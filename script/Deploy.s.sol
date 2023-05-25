pragma solidity 0.6.7;

import 'forge-std/Script.sol';

import {SAFEEngine} from '../src/contracts/SAFEEngine.sol';
import {TaxCollector} from '../src/contracts/TaxCollector.sol';
import {AccountingEngine} from '../src/contracts/AccountingEngine.sol';
import {LiquidationEngine} from '../src/contracts/LiquidationEngine.sol';
import {CoinJoin} from '../src/contracts/utils/CoinJoin.sol';
import {CollateralJoin} from '../src/contracts/utils/CollateralJoin.sol';
import {ETHJoin} from '../src/contracts/utils/ETHJoin.sol';
import {MixedStratSurplusAuctionHouse} from '../src/contracts/SurplusAuctionHouse.sol';
import {DebtAuctionHouse} from '../src/contracts/DebtAuctionHouse.sol';
import {IncreasingDiscountCollateralAuctionHouse} from '../src/contracts/CollateralAuctionHouse.sol';
import {Coin} from '../src/contracts/utils/Coin.sol';
import {GlobalSettlement} from '../src/contracts/GlobalSettlement.sol';
// TODO: import ESM to repo
// import {ESM} from "../src/contracts/ESM.sol";
import {StabilityFeeTreasury} from '../src/contracts/StabilityFeeTreasury.sol';
import {CoinSavingsAccount} from '../src/contracts/CoinSavingsAccount.sol';
import {OracleRelayer} from '../src/contracts/OracleRelayer.sol';

import {OracleForTest} from '../src/contracts/for-test/OracleForTest.sol';

import {GebProxyActions} from '../src/contracts/ProxyActions.sol';

contract GebProxyRegistry {
    mapping(address => DSProxy) public proxies;
    DSProxyFactory factory;

    // --- Events ---
    event Build(address usr, address proxy);

    constructor(address factory_) public {
        factory = DSProxyFactory(factory_);
    }

    // deploys a new proxy instance
    // sets owner of proxy to caller
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
        emit Build(msg.sender, proxy);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build(address owner) public returns (address payable proxy) {
        require(proxies[owner] == DSProxy(payable(address(0))) || proxies[owner].owner() != owner); // Not allow new proxy if the user already has one and remains being the owner
        proxy = factory.build(owner);
        proxies[owner] = DSProxy(proxy);
        emit Build(owner, proxy);
    }
}

contract DSProxy {
    DSProxyCache public cache;  // global cache for contracts
    address public owner;

    function setOwner(address _owner) public {
        owner = _owner;
    }

    constructor(address _cacheAddr) public {
        setCache(_cacheAddr);
        owner = tx.origin;
    }

    receive() external payable {
    }

    // use the proxy to execute calldata _data on contract _code
    function execute(bytes memory _code, bytes memory _data)
        public
        payable
        returns (address target, bytes memory response)
    {
        target = cache.read(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = execute(target, _data);
    }

    function execute(address _target, bytes memory _data)
        public
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "ds-proxy-target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    //set new cache
    function setCache(address _cacheAddr)
        public
        returns (bool)
    {
        require(_cacheAddr != address(0), "ds-proxy-cache-address-required");
        cache = DSProxyCache(_cacheAddr);  // overwrite cache
        return true;
    }
}

contract DSProxyFactory {
    event Created(address indexed sender, address indexed owner, address proxy, address cache);
    mapping(address=>bool) public isProxy;
    DSProxyCache public cache;

    constructor() public {
        cache = new DSProxyCache();
    }

    // deploys a new proxy instance
    // sets owner of proxy to caller
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build(address owner) public returns (address payable proxy) {
        proxy = payable(address(new DSProxy(payable(address(cache)))));
        emit Created(msg.sender, owner, address(proxy), address(cache));
        DSProxy(proxy).setOwner(owner);
        isProxy[proxy] = true;
    }
}

contract DSProxyCache {
    mapping(bytes32 => address) cache;

    function read(bytes memory _code) public view returns (address) {
        bytes32 hash = keccak256(_code);
        return cache[hash];
    }

    function write(bytes memory _code) public returns (address target) {
        assembly {
            target := create(0, add(_code, 0x20), mload(_code))
            switch iszero(extcodesize(target))
            case 1 {
                // throw if contract failed to deploy
                revert(0, 0)
            }
        }
        bytes32 hash = keccak256(_code);
        cache[hash] = target;
    }
}

abstract contract SAFEEngineLike {
    function safes(bytes32, address) virtual public view returns (uint, uint);
    function approveSAFEModification(address) virtual public;
    function transferCollateral(bytes32, address, address, uint) virtual public;
    function transferInternalCoins(address, address, uint) virtual public;
    function modifySAFECollateralization(bytes32, address, address, address, int, int) virtual public;
    function transferSAFECollateralAndDebt(bytes32, address, address, int, int) virtual public;
}

abstract contract LiquidationEngineLike {
    function protectSAFE(bytes32, address, address) virtual external;
}

contract GetSafes {
    function getSafesAsc(address manager, address guy) external view returns (uint[] memory ids, address[] memory safes, bytes32[] memory collateralTypes) {
        uint count = GebSafeManager(manager).safeCount(guy);
        ids = new uint[](count);
        safes = new address[](count);
        collateralTypes = new bytes32[](count);
        uint i = 0;
        uint id = GebSafeManager(manager).firstSAFEID(guy);

        while (id > 0) {
            ids[i] = id;
            safes[i] = GebSafeManager(manager).safes(id);
            collateralTypes[i] = GebSafeManager(manager).collateralTypes(id);
            (,id) = GebSafeManager(manager).safeList(id);
            i++;
        }
    }

    function getSafesDesc(address manager, address guy) external view returns (uint[] memory ids, address[] memory safes, bytes32[] memory collateralTypes) {
        uint count = GebSafeManager(manager).safeCount(guy);
        ids = new uint[](count);
        safes = new address[](count);
        collateralTypes = new bytes32[](count);
        uint i = 0;
        uint id = GebSafeManager(manager).lastSAFEID(guy);

        while (id > 0) {
            ids[i] = id;
            safes[i] = GebSafeManager(manager).safes(id);
            collateralTypes[i] = GebSafeManager(manager).collateralTypes(id);
            (id,) = GebSafeManager(manager).safeList(id);
            i++;
        }
    }
}

contract SAFEHandler {
    constructor(address safeEngine) public {
        SAFEEngineLike(safeEngine).approveSAFEModification(msg.sender);
    }
}

contract GebSafeManager {
    address                   public safeEngine;
    uint                      public safei;               // Auto incremental
    mapping (uint => address) public safes;               // SAFEId => SAFEHandler
    mapping (uint => List)    public safeList;            // SAFEId => Prev & Next SAFEIds (double linked list)
    mapping (uint => address) public ownsSAFE;            // SAFEId => Owner
    mapping (uint => bytes32) public collateralTypes;     // SAFEId => CollateralType

    mapping (address => uint) public firstSAFEID;         // Owner => First SAFEId
    mapping (address => uint) public lastSAFEID;          // Owner => Last SAFEId
    mapping (address => uint) public safeCount;           // Owner => Amount of SAFEs

    mapping (
        address => mapping (
            uint => mapping (
                address => uint
            )
        )
    ) public safeCan;                            // Owner => SAFEId => Allowed Addr => True/False

    mapping (
        address => mapping (
            address => uint
        )
    ) public handlerCan;                        // SAFE handler => Allowed Addr => True/False

    struct List {
        uint prev;
        uint next;
    }

    // --- Events ---
    event AllowSAFE(
        address sender,
        uint safe,
        address usr,
        uint ok
    );
    event AllowHandler(
        address sender,
        address usr,
        uint ok
    );
    event TransferSAFEOwnership(
        address sender,
        uint safe,
        address dst
    );
    event OpenSAFE(address indexed sender, address indexed own, uint indexed safe);
    event ModifySAFECollateralization(
        address sender,
        uint safe,
        int deltaCollateral,
        int deltaDebt
    );
    event TransferCollateral(
        address sender,
        uint safe,
        address dst,
        uint wad
    );
    event TransferCollateral(
        address sender,
        bytes32 collateralType,
        uint safe,
        address dst,
        uint wad
    );
    event TransferInternalCoins(
        address sender,
        uint safe,
        address dst,
        uint rad
    );
    event QuitSystem(
        address sender,
        uint safe,
        address dst
    );
    event EnterSystem(
        address sender,
        address src,
        uint safe
    );
    event MoveSAFE(
        address sender,
        uint safeSrc,
        uint safeDst
    );
    event ProtectSAFE(
        address sender,
        uint safe,
        address liquidationEngine,
        address saviour
    );

    modifier safeAllowed(
        uint safe
    ) {
        require(msg.sender == ownsSAFE[safe] || safeCan[ownsSAFE[safe]][safe][msg.sender] == 1, "safe-not-allowed");
        _;
    }

    modifier handlerAllowed(
        address handler
    ) {
        require(
          msg.sender == handler ||
          handlerCan[handler][msg.sender] == 1,
          "internal-system-safe-not-allowed"
        );
        _;
    }

    constructor(address safeEngine_) public {
        safeEngine = safeEngine_;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0);
    }

    // --- SAFE Manipulation ---

    // Allow/disallow a usr address to manage the safe
    function allowSAFE(
        uint safe,
        address usr,
        uint ok
    ) public safeAllowed(safe) {
        safeCan[ownsSAFE[safe]][safe][usr] = ok;
        emit AllowSAFE(
            msg.sender,
            safe,
            usr,
            ok
        );
    }

    // Allow/disallow a usr address to quit to the sender handler
    function allowHandler(
        address usr,
        uint ok
    ) public {
        handlerCan[msg.sender][usr] = ok;
        emit AllowHandler(
            msg.sender,
            usr,
            ok
        );
    }

    // Open a new safe for a given usr address.
    function openSAFE(
        bytes32 collateralType,
        address usr
    ) public returns (uint) {
        require(usr != address(0), "usr-address-0");

        safei = add(safei, 1);
        safes[safei] = address(new SAFEHandler(safeEngine));
        ownsSAFE[safei] = usr;
        collateralTypes[safei] = collateralType;

        // Add new SAFE to double linked list and pointers
        if (firstSAFEID[usr] == 0) {
            firstSAFEID[usr] = safei;
        }
        if (lastSAFEID[usr] != 0) {
            safeList[safei].prev = lastSAFEID[usr];
            safeList[lastSAFEID[usr]].next = safei;
        }
        lastSAFEID[usr] = safei;
        safeCount[usr] = add(safeCount[usr], 1);

        emit OpenSAFE(msg.sender, usr, safei);
        return safei;
    }

    // Give the safe ownership to a dst address.
    function transferSAFEOwnership(
        uint safe,
        address dst
    ) public safeAllowed(safe) {
        require(dst != address(0), "dst-address-0");
        require(dst != ownsSAFE[safe], "dst-already-owner");

        // Remove transferred SAFE from double linked list of origin user and pointers
        if (safeList[safe].prev != 0) {
            safeList[safeList[safe].prev].next = safeList[safe].next;    // Set the next pointer of the prev safe (if exists) to the next of the transferred one
        }
        if (safeList[safe].next != 0) {                                  // If wasn't the last one
            safeList[safeList[safe].next].prev = safeList[safe].prev;    // Set the prev pointer of the next safe to the prev of the transferred one
        } else {                                                         // If was the last one
            lastSAFEID[ownsSAFE[safe]] = safeList[safe].prev;            // Update last pointer of the owner
        }
        if (firstSAFEID[ownsSAFE[safe]] == safe) {                       // If was the first one
            firstSAFEID[ownsSAFE[safe]] = safeList[safe].next;           // Update first pointer of the owner
        }
        safeCount[ownsSAFE[safe]] = sub(safeCount[ownsSAFE[safe]], 1);

        // Transfer ownership
        ownsSAFE[safe] = dst;

        // Add transferred SAFE to double linked list of destiny user and pointers
        safeList[safe].prev = lastSAFEID[dst];
        safeList[safe].next = 0;
        if (lastSAFEID[dst] != 0) {
            safeList[lastSAFEID[dst]].next = safe;
        }
        if (firstSAFEID[dst] == 0) {
            firstSAFEID[dst] = safe;
        }
        lastSAFEID[dst] = safe;
        safeCount[dst] = add(safeCount[dst], 1);

        emit TransferSAFEOwnership(
            msg.sender,
            safe,
            dst
        );
    }

    // Modify a SAFE's collateralization ratio while keeping the generated COIN or collateral freed in the SAFE handler address.
    function modifySAFECollateralization(
        uint safe,
        int deltaCollateral,
        int deltaDebt
    ) public safeAllowed(safe) {
        address safeHandler = safes[safe];
        SAFEEngineLike(safeEngine).modifySAFECollateralization(
            collateralTypes[safe],
            safeHandler,
            safeHandler,
            safeHandler,
            deltaCollateral,
            deltaDebt
        );
        emit ModifySAFECollateralization(
            msg.sender,
            safe,
            deltaCollateral,
            deltaDebt
        );
    }

    // Transfer wad amount of safe collateral from the safe address to a dst address.
    function transferCollateral(
        uint safe,
        address dst,
        uint wad
    ) public safeAllowed(safe) {
        SAFEEngineLike(safeEngine).transferCollateral(collateralTypes[safe], safes[safe], dst, wad);
        emit TransferCollateral(
            msg.sender,
            safe,
            dst,
            wad
        );
    }

    // Transfer wad amount of any type of collateral (collateralType) from the safe address to a dst address.
    // This function has the purpose to take away collateral from the system that doesn't correspond to the safe but was sent there wrongly.
    function transferCollateral(
        bytes32 collateralType,
        uint safe,
        address dst,
        uint wad
    ) public safeAllowed(safe) {
        SAFEEngineLike(safeEngine).transferCollateral(collateralType, safes[safe], dst, wad);
        emit TransferCollateral(
            msg.sender,
            collateralType,
            safe,
            dst,
            wad
        );
    }

    // Transfer rad amount of COIN from the safe address to a dst address.
    function transferInternalCoins(
        uint safe,
        address dst,
        uint rad
    ) public safeAllowed(safe) {
        SAFEEngineLike(safeEngine).transferInternalCoins(safes[safe], dst, rad);
        emit TransferInternalCoins(
            msg.sender,
            safe,
            dst,
            rad
        );
    }

    // Quit the system, migrating the safe (lockedCollateral, generatedDebt) to a different dst handler
    function quitSystem(
        uint safe,
        address dst
    ) public safeAllowed(safe) handlerAllowed(dst) {
        (uint lockedCollateral, uint generatedDebt) = SAFEEngineLike(safeEngine).safes(collateralTypes[safe], safes[safe]);
        int deltaCollateral = toInt(lockedCollateral);
        int deltaDebt = toInt(generatedDebt);
        SAFEEngineLike(safeEngine).transferSAFECollateralAndDebt(
            collateralTypes[safe],
            safes[safe],
            dst,
            deltaCollateral,
            deltaDebt
        );
        emit QuitSystem(
            msg.sender,
            safe,
            dst
        );
    }

    // Import a position from src handler to the handler owned by safe
    function enterSystem(
        address src,
        uint safe
    ) public handlerAllowed(src) safeAllowed(safe) {
        (uint lockedCollateral, uint generatedDebt) = SAFEEngineLike(safeEngine).safes(collateralTypes[safe], src);
        int deltaCollateral = toInt(lockedCollateral);
        int deltaDebt = toInt(generatedDebt);
        SAFEEngineLike(safeEngine).transferSAFECollateralAndDebt(
            collateralTypes[safe],
            src,
            safes[safe],
            deltaCollateral,
            deltaDebt
        );
        emit EnterSystem(
            msg.sender,
            src,
            safe
        );
    }

    // Move a position from safeSrc handler to the safeDst handler
    function moveSAFE(
        uint safeSrc,
        uint safeDst
    ) public safeAllowed(safeSrc) safeAllowed(safeDst) {
        require(collateralTypes[safeSrc] == collateralTypes[safeDst], "non-matching-safes");
        (uint lockedCollateral, uint generatedDebt) = SAFEEngineLike(safeEngine).safes(collateralTypes[safeSrc], safes[safeSrc]);
        int deltaCollateral = toInt(lockedCollateral);
        int deltaDebt = toInt(generatedDebt);
        SAFEEngineLike(safeEngine).transferSAFECollateralAndDebt(
            collateralTypes[safeSrc],
            safes[safeSrc],
            safes[safeDst],
            deltaCollateral,
            deltaDebt
        );
        emit MoveSAFE(
            msg.sender,
            safeSrc,
            safeDst
        );
    }

    // Choose a SAFE saviour inside LiquidationEngine for the SAFE with id 'safe'
    function protectSAFE(
        uint safe,
        address liquidationEngine,
        address saviour
    ) public safeAllowed(safe) {
        LiquidationEngineLike(liquidationEngine).protectSAFE(
            collateralTypes[safe],
            safes[safe],
            saviour
        );
        emit ProtectSAFE(
            msg.sender,
            safe,
            liquidationEngine,
            saviour
        );
    }
}

contract Deploy is Script {
  bytes32 public constant COLLATERAL_TYPE = bytes32('COLLATERAL');

  SAFEEngine public safeEngine;
  TaxCollector public taxCollector;
  AccountingEngine public accountingEngine;
  LiquidationEngine public liquidationEngine;
  StabilityFeeTreasury public stabilityFeeTreasury;
  CoinSavingsAccount public coinSavingsAccount;

  Coin public coin;
  Coin public protocolToken;
  CoinJoin public coinJoin;
  ETHJoin public collateralJoin;
  CollateralJoin public collateralJoin1;

  MixedStratSurplusAuctionHouse public surplusAuctionHouse;
  DebtAuctionHouse public debtAuctionHouse;
  IncreasingDiscountCollateralAuctionHouse public collateralAuctionHouse;

  OracleRelayer public oracleRelayer;
  OracleForTest public oracleForTest;

  GlobalSettlement public globalSettlement;
  // ESM public esm;

  uint256 public chainId;
  address public deployer;
  uint256 internal _deployerPk = 69; // for tests

  function run() public {
    vm.startBroadcast(_deployerPk);

    // deploy SAFEEngine and OracleRelayer
    safeEngine = new SAFEEngine();
    oracleRelayer = new OracleRelayer(address(safeEngine));
    safeEngine.addAuthorization(address(oracleRelayer));

    // deploy Coin and CoinJoin
    coin = new Coin('HAI Index Token', 'HAI', chainId);
    coinJoin = new CoinJoin(address(safeEngine), address(coin));
    coin.addAuthorization(address(coinJoin));
    safeEngine.addAuthorization(address(coinJoin));

    // deploy ETHJoin
    collateralJoin = new ETHJoin(address(safeEngine), COLLATERAL_TYPE);
    collateralJoin1 = new CollateralJoin(address(safeEngine), COLLATERAL_TYPE, 0x4200000000000000000000000000000000000006);
    safeEngine.addAuthorization(address(collateralJoin));
    safeEngine.addAuthorization(address(collateralJoin1));

    // deploy TaxCollector
    taxCollector = new TaxCollector(address(safeEngine));
    safeEngine.addAuthorization(address(taxCollector));

    // deploy CoinSavingsAccount
    coinSavingsAccount = new CoinSavingsAccount(address(safeEngine));
    safeEngine.addAuthorization(address(coinSavingsAccount));

    // deploy AuctionHouses
    protocolToken = new Coin('Protocol Token', 'TKN', chainId);

    surplusAuctionHouse = new MixedStratSurplusAuctionHouse(address(safeEngine), address(protocolToken));
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    // deploy AccountingEngine
    accountingEngine =
      new AccountingEngine(address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse));

    debtAuctionHouse.modifyParameters('accountingEngine', address(accountingEngine));
    taxCollector.modifyParameters('primaryTaxReceiver', address(accountingEngine));

    surplusAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));

    // deploy StabilityFeeTreasury
    stabilityFeeTreasury = new StabilityFeeTreasury(
          address(safeEngine),
          address(accountingEngine),
          address(coinJoin)
        );

    // deploy LiquidationEngine
    liquidationEngine = new LiquidationEngine(address(safeEngine));
    liquidationEngine.modifyParameters('accountingEngine', address(accountingEngine));

    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    // TODO: deploy ESM, GlobalSettlement, SettlementSurplusAuctioneer

    // deploy CollateralAuctionHouse
    collateralAuctionHouse =
      new IncreasingDiscountCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), COLLATERAL_TYPE);
    collateralAuctionHouse.addAuthorization(address(liquidationEngine));
    // collateralAuctionHouse.addAuthorization(address(globalSettlement));

    liquidationEngine.modifyParameters(COLLATERAL_TYPE, 'collateralAuctionHouse', address(collateralAuctionHouse));
    liquidationEngine.addAuthorization(address(collateralAuctionHouse));

    // TODO: replace for actual oracle
    oracleForTest = new OracleForTest();
    oracleRelayer.modifyParameters(COLLATERAL_TYPE, 'orcl', address(oracleForTest));

    safeEngine.initializeCollateralType(COLLATERAL_TYPE);
    taxCollector.initializeCollateralType(COLLATERAL_TYPE);

    // setup
    safeEngine.modifyParameters('globalDebtCeiling', UINT256_MAX);
    safeEngine.modifyParameters(COLLATERAL_TYPE, 'debtCeiling', UINT256_MAX);
    safeEngine.modifyParameters(COLLATERAL_TYPE, 'safetyPrice', 1e18);

    new GebProxyActions();
    address _factory = address(new DSProxyFactory());
    new GebProxyRegistry(_factory);
    new GetSafes();
    new GebSafeManager(address(safeEngine));
    new DSProxyFactory();

    vm.stopBroadcast();
  }

  function revoke() public {
    safeEngine.removeAuthorization(deployer);
    oracleRelayer.removeAuthorization(deployer);
    coin.removeAuthorization(deployer);
    coinJoin.removeAuthorization(deployer);
    taxCollector.removeAuthorization(deployer);
    coinSavingsAccount.removeAuthorization(deployer);
    protocolToken.removeAuthorization(deployer);
    surplusAuctionHouse.removeAuthorization(deployer);
    debtAuctionHouse.removeAuthorization(deployer);
    collateralAuctionHouse.removeAuthorization(deployer);
    stabilityFeeTreasury.removeAuthorization(deployer);
    liquidationEngine.removeAuthorization(deployer);
    accountingEngine.removeAuthorization(deployer);
  }
}

contract DeployMainnet is Deploy {
  constructor() public {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
    chainId = 10;
  }
}

contract DeployGoerli is Deploy {
  constructor() public {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
    chainId = 420;
  }
}
