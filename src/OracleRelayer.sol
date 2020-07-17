/// OracleRelayer.sol

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

pragma solidity ^0.6.7;

import "./Logging.sol";

abstract contract CDPEngineLike {
    function modifyParameters(bytes32, bytes32, uint) virtual external;
}

abstract contract OracleLike {
    function getResultWithValidity() virtual public view returns (bytes32, bool);
}

contract OracleRelayer is Logging {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external emitLog isAuthorized { authorizedAccounts[account] = 1; }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external emitLog isAuthorized { authorizedAccounts[account] = 0; }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "OracleRelayer/account-not-authorized");
        _;
    }

    // --- Data ---
    struct CollateralType {
        // Usually an oracle security module that enforces delays to fresh price feeds
        OracleLike orcl;
        // CRatio used to compute the 'safePrice' - the price used when generating debt in CDPEngine
        uint256 safetyCRatio;
        // CRatio used to compute the 'liquidationPrice' - the price used when liquidating CDPs
        uint256 liquidationCRatio;
    }

    // Data about each collateral type
    mapping (bytes32 => CollateralType) public collateralTypes;

    CDPEngineLike public cdpEngine;
    // The force that changes the system users' incentives by changing the redemption price
    uint256 public redemptionRate;
    // Last time when the redemption price was changed
    uint256 public redemptionPriceUpdateTime;
    // Whether this contract is enabled
    uint256 public contractEnabled;

    // Virtual redemption price (not the most updated value)
    uint256 internal _redemptionPrice;

    // --- Events ---
    event UpdateCollateralPrice(
      bytes32 collateralType,
      bytes32 priceFeedValue,
      uint256 safetyPrice,
      uint256 liquidationPrice
    );

    // --- Init ---
    constructor(address cdpEngine_) public {
        authorizedAccounts[msg.sender] = 1;
        cdpEngine  = CDPEngineLike(cdpEngine_);
        _redemptionPrice = RAY;
        redemptionRate   = RAY;
        redemptionPriceUpdateTime  = now;
        contractEnabled = 1;
    }

    // --- Math ---
    uint constant RAY = 10 ** 27;

    function subtract(uint x, uint y) internal pure returns (uint z) {
        z = x - y;
        require(z <= x);
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function rmultiply(uint x, uint y) internal pure returns (uint z) {
        // alsites rounds down
        z = multiply(x, y) / RAY;
    }
    function rdivide(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, RAY) / y;
    }
    function rpower(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }

    // --- Administration ---
    /**
     * @notice Modify oracle price feed addresses
     * @param collateralType Collateral who's oracle we change
     * @param parameter Name of the parameter
     * @param addr New oracle address
     */
    function modifyParameters(
        bytes32 collateralType,
        bytes32 parameter,
        address addr
    ) external emitLog isAuthorized {
        require(contractEnabled == 1, "OracleRelayer/contract-not-enabled");
        if (parameter == "orcl") collateralTypes[collateralType].orcl = OracleLike(addr);
        else revert("OracleRelayer/modify-unrecognized-param");
    }
    /**
     * @notice Modify redemption related parameters
     * @param parameter Name of the parameter
     * @param data New param value
     */
    function modifyParameters(bytes32 parameter, uint data) external emitLog isAuthorized {
        require(contractEnabled == 1, "OracleRelayer/contract-not-enabled");
        require(data > 0, "OracleRelayer/null-data");
        if (parameter == "redemptionPrice") _redemptionPrice = data;
        else if (parameter == "redemptionRate") {
          require(now == redemptionPriceUpdateTime, "OracleRelayer/redemption-price-not-updated");
          redemptionRate = data;
        }
        else revert("OracleRelayer/modify-unrecognized-param");
    }
    /**
     * @notice Modify CRatio related parameters
     * @param collateralType Collateral who's parameters we change
     * @param parameter Name of the parameter
     * @param data New param value
     */
    function modifyParameters(
        bytes32 collateralType,
        bytes32 parameter,
        uint data
    ) external emitLog isAuthorized {
        require(contractEnabled == 1, "OracleRelayer/contract-not-enabled");
        if (parameter == "safetyCRatio") {
          require(data >= collateralTypes[collateralType].liquidationCRatio, "OracleRelayer/safety-lower-than-liquidation-cratio");
          collateralTypes[collateralType].safetyCRatio = data;
        }
        else if (parameter == "liquidationCRatio") {
          require(data <= collateralTypes[collateralType].safetyCRatio, "OracleRelayer/safety-lower-than-liquidation-cratio");
          collateralTypes[collateralType].liquidationCRatio = data;
        }
        else revert("OracleRelayer/modify-unrecognized-param");
    }

    // --- Redemption Price Update ---
    /**
     * @notice Update the redemption price according to the current redemption rate
     */
    function updateRedemptionPrice() internal returns (uint) {
        // Update redemption price
        _redemptionPrice = rmultiply(
          rpower(redemptionRate, subtract(now, redemptionPriceUpdateTime), RAY),
          _redemptionPrice
        );
        redemptionPriceUpdateTime = now;
        // Return updated redemption price
        return _redemptionPrice;
    }
    /**
     * @notice Fetch the latest redemption price by first updating it
     */
    function redemptionPrice() public returns (uint) {
        if (now > redemptionPriceUpdateTime) return updateRedemptionPrice();
        return _redemptionPrice;
    }

    // --- Update value ---
    /**
     * @notice Update the collateral price inside the system (inside CDPEngine)
     * @param collateralType The collateral we want to update prices (safety and liquidation prices) for
     */
    function updateCollateralPrice(bytes32 collateralType) external {
        (bytes32 priceFeedValue, bool hasValidValue) =
          collateralTypes[collateralType].orcl.getResultWithValidity();
        uint redemptionPrice_ = redemptionPrice();
        uint256 safetyPrice_ = hasValidValue ? rdivide(rdivide(multiply(uint(priceFeedValue), 10 ** 9), redemptionPrice_), collateralTypes[collateralType].safetyCRatio) : 0;
        uint256 liquidationPrice_ = (hasValidValue && collateralTypes[collateralType].liquidationCRatio > 0) ? rdivide(rdivide(multiply(uint(priceFeedValue), 10 ** 9), redemptionPrice_), collateralTypes[collateralType].liquidationCRatio) : 0;

        cdpEngine.modifyParameters(collateralType, "safetyPrice", safetyPrice_);
        cdpEngine.modifyParameters(collateralType, "liquidationPrice", liquidationPrice_);
        emit UpdateCollateralPrice(collateralType, priceFeedValue, safetyPrice_, liquidationPrice_);
    }

    /**
     * @notice Disable this contract (normally called by GlobalSettlement)
     */
    function disableContract() external emitLog isAuthorized {
        contractEnabled = 0;
    }

    /**
     * @notice Fetch the safety CRatio of a specific collateral type
     * @param collateralType The collateral price we want the safety CRatio for
     */
    function safetyCRatio(bytes32 collateralType) public view returns (uint256) {
        return collateralTypes[collateralType].safetyCRatio;
    }
    /**
     * @notice Fetch the liquidation CRatio of a specific collateral type
     * @param collateralType The collateral price we want the liquidation CRatio for
     */
    function liquidationCRatio(bytes32 collateralType) public view returns (uint256) {
        return collateralTypes[collateralType].liquidationCRatio;
    }
    /**
     * @notice Fetch the oracle price feed of a specific collateral type
     * @param collateralType The collateral price we want the oracle price feed for
     */
    function orcl(bytes32 collateralType) public view returns (address) {
        return address(collateralTypes[collateralType].orcl);
    }
}
