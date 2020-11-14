/// LiquidationEngine.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.7;

abstract contract CollateralAuctionHouseLike {
    function startAuction(
      address forgoneCollateralReceiver,
      address initialBidder,
      uint amountToRaise,
      uint collateralToSell,
      uint initialBid
    ) virtual public returns (uint);
}
abstract contract SAFESaviourLike {
    function saveSAFE(address,bytes32,address) virtual external returns (bool,uint256,uint256);
}
abstract contract SAFEEngineLike {
    function collateralTypes(bytes32) virtual public view returns (
        uint256 debtAmount,        // [wad]
        uint256 accumulatedRate,   // [ray]
        uint256 safetyPrice,       // [ray]
        uint256 debtCeiling,       // [rad]
        uint256 debtFloor,         // [rad]
        uint256 liquidationPrice   // [ray]
    );
    function safes(bytes32,address) virtual public view returns (
        uint256 lockedCollateral,  // [wad]
        uint256 generatedDebt      // [wad]
    );
    function confiscateSAFECollateralAndDebt(bytes32,address,address,address,int,int) virtual external;
    function canModifySAFE(address, address) virtual public view returns (bool);
    function approveSAFEModification(address) virtual external;
    function denySAFEModification(address) virtual external;
}
abstract contract AccountingEngineLike {
    function pushDebtToQueue(uint) virtual external;
}

contract LiquidationEngine {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "LiquidationEngine/account-not-authorized");
        _;
    }

    // --- SAFE Saviours ---
    // Contracts that can save SAFEs from liquidation
    mapping (address => uint) public safeSaviours;
    /**
    * @notice Authed function to add contracts that can save SAFEs from liquidation
    * @param saviour SAFE saviour contract to be whitelisted
    **/
    function connectSAFESaviour(address saviour) external isAuthorized {
        (bool ok, uint256 collateralAdded, uint256 liquidatorReward) =
          SAFESaviourLike(saviour).saveSAFE(address(this), "", address(0));
        require(ok, "LiquidationEngine/saviour-not-ok");
        require(both(collateralAdded == uint(-1), liquidatorReward == uint(-1)), "LiquidationEngine/invalid-amounts");
        safeSaviours[saviour] = 1;
        emit ConnectSAFESaviour(saviour);
    }
    /**
    * @notice Governance used function to remove contracts that can save SAFEs from liquidation
    * @param saviour SAFE saviour contract to be removed
    **/
    function disconnectSAFESaviour(address saviour) external isAuthorized {
        safeSaviours[saviour] = 0;
        emit DisconnectSAFESaviour(saviour);
    }

    // --- Data ---
    struct CollateralType {
        // Address of the collateral auction house handling liquidations for this collateral type
        address collateralAuctionHouse;
        // Penalty applied to every liquidation involving this collateral type. Discourages SAFE users from bidding on their own SAFEs
        uint256 liquidationPenalty;                                                                                                   // [wad]
        // Max amount of system coins to request in one auction
        uint256 liquidationQuantity;                                                                                                  // [rad]
    }

    // Collateral types included in the system
    mapping (bytes32 => CollateralType)              public collateralTypes;
    // Saviour contract chosen for each SAFE by its creator
    mapping (bytes32 => mapping(address => address)) public chosenSAFESaviour;
    // Mutex used to block against re-entrancy when 'liquidateSAFE' passes execution to a saviour
    mapping (bytes32 => mapping(address => uint8))   public mutex;

    // Max amount of system coins that can be on liquidation at any time
    uint256 public onAuctionSystemCoinLimit;                                // [rad]
    // Current amount of system coins out for liquidation
    uint256 public currentOnAuctionSystemCoins;                             // [rad]
    // Whether this contract is enabled
    uint256 public contractEnabled;

    SAFEEngineLike       public safeEngine;
    AccountingEngineLike public accountingEngine;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ConnectSAFESaviour(address saviour);
    event DisconnectSAFESaviour(address saviour);
    event UpdateCurrentOnAuctionSystemCoins(uint currentOnAuctionSystemCoins);
    event ModifyParameters(bytes32 parameter, uint256 data);
    event ModifyParameters(bytes32 parameter, address data);
    event ModifyParameters(
      bytes32 collateralType,
      bytes32 parameter,
      uint data
    );
    event ModifyParameters(
      bytes32 collateralType,
      bytes32 parameter,
      address data
    );
    event DisableContract();
    event Liquidate(
      bytes32 indexed collateralType,
      address indexed safe,
      uint256 collateralAmount,
      uint256 debtAmount,
      uint256 amountToRaise,
      address collateralAuctioneer,
      uint256 auctionId
    );
    event SaveSAFE(
      bytes32 indexed collateralType,
      address indexed safe,
      uint256 collateralAdded
    );
    event FailedSAFESave(bytes failReason);
    event ProtectSAFE(
      bytes32 collateralType,
      address safe,
      address saviour
    );

    // --- Init ---
    constructor(address safeEngine_) public {
        authorizedAccounts[msg.sender] = 1;
        safeEngine = SAFEEngineLike(safeEngine_);
        onAuctionSystemCoinLimit = uint(-1);
        contractEnabled = 1;
        emit AddAuthorization(msg.sender);
        emit ModifyParameters("onAuctionSystemCoinLimit", uint(-1));
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant MAX_LIQUIDATION_QUANTITY = uint256(-1) / RAY;

    function addition(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function subtract(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function rmultiply(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, y) / RAY;
    }
    function minimum(uint x, uint y) internal pure returns (uint z) {
        if (x > y) { z = y; } else { z = x; }
    }

    // --- Utils ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Administration ---
    /*
    * @notice Modify uint256 parameters
    * @param paramter The name of the parameter modified
    * @param data Value for the new parameter
    */
    function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
        if (parameter == "onAuctionSystemCoinLimit") onAuctionSystemCoinLimit = data;
        else revert("LiquidationEngine/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }
    /**
     * @notice Modify contract integrations
     * @param parameter The name of the parameter modified
     * @param data New address for the parameter
     */
    function modifyParameters(bytes32 parameter, address data) external isAuthorized {
        if (parameter == "accountingEngine") accountingEngine = AccountingEngineLike(data);
        else revert("LiquidationEngine/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }
    /**
     * @notice Modify liquidation params
     * @param collateralType The collateral type we change parameters for
     * @param parameter The name of the parameter modified
     * @param data New value for the parameter
     */
    function modifyParameters(
        bytes32 collateralType,
        bytes32 parameter,
        uint data
    ) external isAuthorized {
        if (parameter == "liquidationPenalty") collateralTypes[collateralType].liquidationPenalty = data;
        else if (parameter == "liquidationQuantity") {
          require(data <= MAX_LIQUIDATION_QUANTITY, "LiquidationEngine/liquidation-quantity-overflow");
          collateralTypes[collateralType].liquidationQuantity = data;
        }
        else revert("LiquidationEngine/modify-unrecognized-param");
        emit ModifyParameters(
          collateralType,
          parameter,
          data
        );
    }
    /**
     * @notice Modify collateral auction integration
     * @param collateralType The collateral type we change parameters for
     * @param parameter The name of the integration modified
     * @param data New address for the integration contract
     */
    function modifyParameters(
        bytes32 collateralType,
        bytes32 parameter,
        address data
    ) external isAuthorized {
        if (parameter == "collateralAuctionHouse") {
            safeEngine.denySAFEModification(collateralTypes[collateralType].collateralAuctionHouse);
            collateralTypes[collateralType].collateralAuctionHouse = data;
            safeEngine.approveSAFEModification(data);
        }
        else revert("LiquidationEngine/modify-unrecognized-param");
        emit ModifyParameters(
            collateralType,
            parameter,
            data
        );
    }
    /**
     * @notice Disable this contract (normally called by GlobalSettlement)
     */
    function disableContract() external isAuthorized {
        contractEnabled = 0;
        emit DisableContract();
    }

    // --- SAFE Liquidation ---
    /**
     * @notice Choose a saviour contract for your SAFE
     * @param collateralType The SAFE's collateral type
     * @param safe The SAFE's address
     * @param saviour The chosen saviour
     */
    function protectSAFE(
        bytes32 collateralType,
        address safe,
        address saviour
    ) external {
        require(safeEngine.canModifySAFE(safe, msg.sender), "LiquidationEngine/cannot-modify-safe");
        require(saviour == address(0) || safeSaviours[saviour] == 1, "LiquidationEngine/saviour-not-authorized");
        chosenSAFESaviour[collateralType][safe] = saviour;
        emit ProtectSAFE(
            collateralType,
            safe,
            saviour
        );
    }
    /**
     * @notice Liquidate a SAFE
     * @param collateralType The SAFE's collateral type
     * @param safe The SAFE's address
     */
    function liquidateSAFE(bytes32 collateralType, address safe) external returns (uint auctionId) {
        require(mutex[collateralType][safe] == 0, "LiquidationEngine/non-null-mutex");
        mutex[collateralType][safe] = 1;

        (, uint accumulatedRate, , , uint debtFloor, uint liquidationPrice) = safeEngine.collateralTypes(collateralType);
        (uint safeCollateral, uint safeDebt) = safeEngine.safes(collateralType, safe);

        require(contractEnabled == 1, "LiquidationEngine/contract-not-enabled");
        require(both(
          liquidationPrice > 0,
          multiply(safeCollateral, liquidationPrice) < multiply(safeDebt, accumulatedRate)
        ), "LiquidationEngine/safe-not-unsafe");
        require(
          both(currentOnAuctionSystemCoins < onAuctionSystemCoinLimit,
          subtract(onAuctionSystemCoinLimit, currentOnAuctionSystemCoins) >= debtFloor),
          "LiquidationEngine/liquidation-limit-hit"
        );

        if (chosenSAFESaviour[collateralType][safe] != address(0) &&
            safeSaviours[chosenSAFESaviour[collateralType][safe]] == 1) {
          try SAFESaviourLike(chosenSAFESaviour[collateralType][safe]).saveSAFE(msg.sender, collateralType, safe)
            returns (bool ok, uint256 collateralAdded, uint256) {
            if (both(ok, collateralAdded > 0)) {
              emit SaveSAFE(collateralType, safe, collateralAdded);
            }
          } catch (bytes memory revertReason) {
            emit FailedSAFESave(revertReason);
          }
        }

        // Checks that the saviour didn't take collateral or add more debt to the SAFE
        {
          (uint newSafeCollateral, uint newSafeDebt) = safeEngine.safes(collateralType, safe);
          require(both(newSafeCollateral >= safeCollateral, newSafeDebt <= safeDebt), "LiquidationEngine/invalid-safe-saviour-operation");
        }

        (, accumulatedRate, , , , liquidationPrice) = safeEngine.collateralTypes(collateralType);
        (safeCollateral, safeDebt) = safeEngine.safes(collateralType, safe);

        if (both(liquidationPrice > 0, multiply(safeCollateral, liquidationPrice) < multiply(safeDebt, accumulatedRate))) {
          CollateralType memory collateralData = collateralTypes[collateralType];

          uint limitAdjustedDebt = minimum(
            safeDebt,
            multiply(minimum(collateralData.liquidationQuantity, subtract(onAuctionSystemCoinLimit, currentOnAuctionSystemCoins)), WAD) / accumulatedRate / collateralData.liquidationPenalty
          );
          uint collateralToSell = minimum(safeCollateral, multiply(safeCollateral, limitAdjustedDebt) / safeDebt);

          require(both(limitAdjustedDebt > 0, collateralToSell > 0), "LiquidationEngine/null-auction");
          require(both(collateralToSell <= 2**255, limitAdjustedDebt <= 2**255), "LiquidationEngine/collateral-or-debt-overflow");
          // This can leave the SAFE with generatedDebt < debtFloor
          safeEngine.confiscateSAFECollateralAndDebt(
            collateralType, safe, address(this), address(accountingEngine), -int(collateralToSell), -int(limitAdjustedDebt)
          );
          accountingEngine.pushDebtToQueue(multiply(limitAdjustedDebt, accumulatedRate));

          {
            uint amountToRaise_         = multiply(multiply(limitAdjustedDebt, accumulatedRate), collateralData.liquidationPenalty) / WAD;
            currentOnAuctionSystemCoins = addition(currentOnAuctionSystemCoins, amountToRaise_);

            auctionId = CollateralAuctionHouseLike(collateralData.collateralAuctionHouse).startAuction(
              { forgoneCollateralReceiver: safe
              , initialBidder: address(accountingEngine)
              , amountToRaise: amountToRaise_
              , collateralToSell: collateralToSell
              , initialBid: 0
             });

             emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
          }

          emit Liquidate(collateralType, safe, collateralToSell, limitAdjustedDebt, multiply(limitAdjustedDebt, accumulatedRate), collateralData.collateralAuctionHouse, auctionId);
        }

        mutex[collateralType][safe] = 0;
    }
    function removeCoinsFromAuction(uint rad) public isAuthorized {
        currentOnAuctionSystemCoins = subtract(currentOnAuctionSystemCoins, rad);
        emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
    }
}
