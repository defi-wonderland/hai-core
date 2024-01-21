// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Contracts} from '@script/Contracts.s.sol';

import {
  IBaseOracle,
  IAccountingEngine,
  ICollateralAuctionHouse,
  IDebtAuctionHouse,
  ISurplusAuctionHouse,
  IOracleRelayer,
  ISAFEEngine,
  ILiquidationEngine,
  IStabilityFeeTreasury,
  IPIDController,
  IPIDRateSetter,
  ITaxCollector,
  IGlobalSettlement,
  IPostSettlementSurplusAuctionHouse,
  IHaiGovernor,
  ITokenDistributor,
  IModifiable
} from '@script/Contracts.s.sol';

import {WAD, RAY, RAD} from '@libraries/Math.sol';

// --- Utils ---

// HAI Params
bytes32 constant HAI = bytes32('HAI'); // 0x4841490000000000000000000000000000000000000000000000000000000000
uint256 constant HAI_USD_INITIAL_PRICE = 1e18; // 1 HAI = 1 USD
uint256 constant HAI_ETH_INITIAL_PRICE = 0.0005e18; // 2000 HAI = 1 ETH
int24 constant HAI_ETH_INITIAL_TICK = 76_013; // ~2000 HAI = 1 ETH

uint24 constant HAI_POOL_FEE_TIER = 3000; // 0.3 %
uint16 constant HAI_POOL_OBSERVATION_CARDINALITY = 5000; // Safest cardinality would be 43.2k (at 2s per block, 1d TWAP)

// Collateral Names
bytes32 constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
bytes32 constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
bytes32 constant WSTETH = bytes32('WSTETH'); // 0x5753544554480000000000000000000000000000000000000000000000000000
bytes32 constant OP = bytes32('OP'); // 0x4f50000000000000000000000000000000000000000000000000000000000000
bytes32 constant WBTC = bytes32('WBTC'); // 0x5742544300000000000000000000000000000000000000000000000000000000
bytes32 constant STONES = bytes32('STONES'); // 0x53544f4e45530000000000000000000000000000000000000000000000000000
bytes32 constant TOTEM = bytes32('TOTEM'); // 0x544f54454d000000000000000000000000000000000000000000000000000000

uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;
uint256 constant MINUS_1_PERCENT_PER_HOUR = 999_997_208_243_937_652_252_849_536;
uint256 constant MINUS_90_PERCENT_PER_YEAR = 99_999_999_999_997_789_272_222_624;
uint256 constant HALF_LIFE_30_DAYS = 999_999_711_200_000_000_000_000_000;
uint256 constant PLUS_1_5_PERCENT_PER_YEAR = 1_000_000_000_472_114_805_215_157_978;
uint256 constant PLUS_2_PERCENT_PER_YEAR = 1_000_000_000_627_937_192_491_029_810;
uint256 constant PLUS_5_PERCENT_PER_YEAR = 1_000_000_001_547_125_957_863_212_448;
uint256 constant PLUS_950_PERCENT_PER_YEAR = 1_000_000_074_561_623_060_142_516_377;

// NOTE: RAI values are imported from https://etherscan.io/address/0x5CC4878eA3E6323FdA34b3D28551E1543DEe54C6
uint256 constant PROPORTIONAL_GAIN = 111_001_102_931; // 50% of RAI's
uint256 constant INTEGRAL_GAIN = 32_884; // 200% of RAI's

// Job Params
uint256 constant JOB_REWARD = 5e18; // 5 HAI

/**
 * @title Params
 * @notice This contract initializes all the contract parameters structs, so that they're inherited and available throughout scripts scopes.
 */
abstract contract Params {
  /**
   * @notice Initializes the parameters of the contracts, as many depend on the contracts addresses and need to be dynamically loaded.
   */
  function _getEnvironmentParams() internal virtual;

  // --- Contracts params ---

  ISAFEEngine.SAFEEngineParams _safeEngineParams;
  mapping(bytes32 => ISAFEEngine.SAFEEngineCollateralParams) _safeEngineCParams;

  IOracleRelayer.OracleRelayerParams _oracleRelayerParams;
  mapping(bytes32 => IOracleRelayer.OracleRelayerCollateralParams) _oracleRelayerCParams;
  IPIDController.PIDControllerParams _pidControllerParams;
  IPIDController.ControllerGains _pidControllerGains;
  IPIDRateSetter.PIDRateSetterParams _pidRateSetterParams;

  IAccountingEngine.AccountingEngineParams _accountingEngineParams;
  IDebtAuctionHouse.DebtAuctionHouseParams _debtAuctionHouseParams;
  ISurplusAuctionHouse.SurplusAuctionHouseParams _surplusAuctionHouseParams;
  ILiquidationEngine.LiquidationEngineParams _liquidationEngineParams;
  mapping(bytes32 => ILiquidationEngine.LiquidationEngineCollateralParams) _liquidationEngineCParams;
  mapping(bytes32 => ICollateralAuctionHouse.CollateralAuctionHouseParams) _collateralAuctionHouseParams;

  IStabilityFeeTreasury.StabilityFeeTreasuryParams _stabilityFeeTreasuryParams;
  ITaxCollector.TaxCollectorParams _taxCollectorParams;
  mapping(bytes32 => ITaxCollector.TaxCollectorCollateralParams) _taxCollectorCParams;
  ITaxCollector.TaxReceiver[] _taxCollectorSecondaryTaxReceiver;

  IGlobalSettlement.GlobalSettlementParams _globalSettlementParams;
  IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams _postSettlementSAHParams;

  // --- Governor params ---
  IHaiGovernor.HaiGovernorParams _governorParams;
  ITokenDistributor.TokenDistributorParams _tokenDistributorParams;
}

/**
 * @title ParamChecker
 * @notice This library sets the parameters of the contracts, one by one, ensuring that they're set fully and correctly.
 */
library ParamChecker {
  // --- Helper functions ---

  function _checkParams(address _modifiable, bytes memory _params) internal view {
    bytes memory _callData = abi.encodeWithSignature('params()');
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_params.length);

    require(keccak256(_params) != keccak256(_empty), 'Empty params');
    require(keccak256(_params) == keccak256(_returnData), 'Incorrect params');
  }

  function _checkCParams(address _modifiable, bytes32 _cType, bytes memory _cParams) internal view {
    bytes memory _callData = abi.encodeWithSignature('cParams(bytes32)', _cType);
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_cParams.length);

    require(keccak256(_cParams) != keccak256(_empty), 'Empty params');
    require(keccak256(_cParams) == keccak256(_returnData), 'Incorrect params');
  }
}
