// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployGoerli} from '@script/Deploy.s.sol';

import {ParamChecker, WETH, WSTETH, OP, WBTC, STONES} from '@script/Params.s.sol';
import {OP_OPTIMISM} from '@script/Registry.s.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';

import '@script/Contracts.s.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
  uint256 _governorAccounts;

  // SAFEEngine
  function test_SAFEEngine_Bytecode() public {
    assertEq(address(safeEngine).code, type(SAFEEngine).runtimeCode);
  }

  function test_SAFEEngine_Auth() public {
    assertEq(safeEngine.authorizedAccounts(address(oracleRelayer)), true);
    assertEq(safeEngine.authorizedAccounts(address(taxCollector)), true);
    assertEq(safeEngine.authorizedAccounts(address(debtAuctionHouse)), true);
    assertEq(safeEngine.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(safeEngine.authorizedAccounts(address(globalSettlement)), true);

    assertEq(safeEngine.authorizedAccounts(address(coinJoin)), true);
    assertEq(safeEngine.authorizedAccounts(address(collateralJoinFactory)), true);

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      assertEq(safeEngine.authorizedAccounts(address(collateralJoin[collateralTypes[_i]])), true);
    }

    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));

    // 7 contracts + 1 for each collateral type (cJoin) + governor accounts
    assertEq(safeEngine.authorizedAccounts().length, 7 + collateralTypes.length + _governorAccounts);
  }

  function test_SAFEEngine_Params() public view {
    ParamChecker._checkParams(address(safeEngine), abi.encode(_safeEngineParams));
  }

  // OracleRelayer
  function test_OracleRelayer_Bytecode() public {
    assertEq(address(oracleRelayer).code, type(OracleRelayer).runtimeCode);
  }

  function test_OracleRelayer_Auth() public {
    assertEq(oracleRelayer.authorizedAccounts(address(pidRateSetter)), true);
    assertEq(oracleRelayer.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(oracleRelayer.authorizedAccounts().length, 2 + _governorAccounts);
  }

  // AccountingEngine
  function test_AccountingEngine_Bytecode() public {
    assertEq(address(accountingEngine).code, type(AccountingEngine).runtimeCode);
  }

  function test_AccountingEngine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(accountingEngine.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(accountingEngine.authorizedAccounts().length, 2 + _governorAccounts);
  }

  function test_AccountingEntine_Params() public view {
    ParamChecker._checkParams(address(accountingEngine), abi.encode(_accountingEngineParams));
  }

  // SystemCoin
  function test_SystemCoin_Bytecode_MANUAL_CHECK() public {
    // Not possible to check bytecode because it has immutable storage
    // Needs to be manually checked
  }

  function test_SystemCoin_Auth() public {
    assertEq(systemCoin.authorizedAccounts(address(coinJoin)), true);

    // 1 contract + governor accounts
    assertEq(systemCoin.authorizedAccounts().length, 1 + _governorAccounts);
  }

  // ProtocolToken
  function test_ProtocolToken_Bytecode_MANUAL_CHECK() public {
    // Not possible to check bytecode because it has immutable storage
    // Needs to be manually checked
  }

  function test_ProtocolToken_Auth() public {
    assertEq(protocolToken.authorizedAccounts(address(debtAuctionHouse)), true);

    // 1 contract + governor accounts
    assertEq(protocolToken.authorizedAccounts().length, 1 + _governorAccounts);
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Bytecode() public {
    assertEq(address(surplusAuctionHouse).code, type(SurplusAuctionHouse).runtimeCode);
  }

  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), true);

    // 1 contract + governor accounts
    assertEq(surplusAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_SurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(surplusAuctionHouse), abi.encode(_surplusAuctionHouseParams));
  }

  // DebtAuctionHouse
  function test_DebtAuctionHouse_Bytecode() public {
    assertEq(address(debtAuctionHouse).code, type(DebtAuctionHouse).runtimeCode);
  }

  function test_DebtAuctionHouse_Auth() public {
    assertEq(debtAuctionHouse.authorizedAccounts(address(accountingEngine)), true);

    // 1 contract + governor accounts
    assertEq(debtAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_DebtAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(debtAuctionHouse), abi.encode(_debtAuctionHouseParams));
  }

  // CollateralAuctionHouse
  function test_CollateralAuctionHouseFactory_Bytecode() public {
    assertEq(address(collateralAuctionHouseFactory).code, type(CollateralAuctionHouseFactory).runtimeCode);
  }

  function test_CollateralAuctionHouseFactory_Auth() public {
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(collateralAuctionHouseFactory.authorizedAccounts().length, 2 + _governorAccounts);
  }

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(collateralAuctionHouseFactory)), true);

      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), true);
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(governor)), true);

      // 1 contract (liquidation engine and governor are authorized in the factory)
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts().length, 1);
    }
  }

  function test_CollateralAuctionHouse_Params() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(
        address(collateralAuctionHouseFactory), _cType, abi.encode(_collateralAuctionHouseParams[_cType])
      );
    }
  }

  // LiquidationEngine
  function test_LiquidationEngine_Bytecode() public {
    assertEq(address(liquidationEngine).code, type(LiquidationEngine).runtimeCode);
  }

  function test_LiquidationEngine_Auth() public {
    assertEq(liquidationEngine.authorizedAccounts(address(globalSettlement)), true);

    // 1 contract + 1 per collateralType + governor accounts
    assertEq(liquidationEngine.authorizedAccounts().length, 1 + collateralTypes.length + _governorAccounts);
  }

  function test_LiquidationEngine_Params() public view {
    ParamChecker._checkParams(address(liquidationEngine), abi.encode(_liquidationEngineParams));
  }

  // PIDController
  function test_PIDController_Bytecode() public {
    assertEq(address(pidController).code, type(PIDController).runtimeCode);
  }

  function test_PIDController_Auth() public {
    // only governor
    assertEq(pidController.authorizedAccounts().length, _governorAccounts);
  }

  function test_PIDController_Params() public view {
    ParamChecker._checkParams(address(pidController), abi.encode(_pidControllerParams));
  }

  // PIDRateSetter
  function test_PIDRateSetter_Bytecode() public {
    assertEq(address(pidRateSetter).code, type(PIDRateSetter).runtimeCode);
  }

  function test_PIDRateSetter_Auth() public {
    // only governor
    assertEq(pidRateSetter.authorizedAccounts().length, _governorAccounts);
  }

  function test_PIDRateSetter_Params() public view {
    ParamChecker._checkParams(address(pidRateSetter), abi.encode(_pidRateSetterParams));
  }

  // TaxCollector
  function test_TaxCollector_Bytecode() public {
    assertEq(address(taxCollector).code, type(TaxCollector).runtimeCode);
  }

  function test_TaxCollector_Auth() public {
    // only governor
    assertEq(taxCollector.authorizedAccounts().length, _governorAccounts);
  }

  function test_TaxCollector_Params() public view {
    ParamChecker._checkParams(address(taxCollector), abi.encode(_taxCollectorParams));
  }

  // StabilityFeeTreasury
  function test_StabilityFeeTreasury_Bytecode() public {
    assertEq(address(stabilityFeeTreasury).code, type(StabilityFeeTreasury).runtimeCode);
  }

  function test_StabilityFeeTreasury_Auth() public {
    assertEq(stabilityFeeTreasury.authorizedAccounts(address(globalSettlement)), true);

    // 1 contract + governor accounts
    assertEq(stabilityFeeTreasury.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_StabilityFeeTreasury_Params() public view {
    ParamChecker._checkParams(address(stabilityFeeTreasury), abi.encode(_stabilityFeeTreasuryParams));
  }

  // GlobalSettlement
  function test_GlobalSettlement_Bytecode() public {
    assertEq(address(globalSettlement).code, type(GlobalSettlement).runtimeCode);
  }

  function test_GlobalSettlement_Auth() public {
    // only governor
    assertEq(globalSettlement.authorizedAccounts().length, _governorAccounts);
  }

  function test_GlobalSettlement_Params() public view {
    ParamChecker._checkParams(address(globalSettlement), abi.encode(_globalSettlementParams));
  }

  // PostSettlementSurplusAuctionHouse
  function test_PostSettlementSurplusAuctionHouse_Bytecode() public {
    assertEq(address(postSettlementSurplusAuctionHouse).code, type(PostSettlementSurplusAuctionHouse).runtimeCode);
  }

  function test_PostSettlementSurplusAuctionHouse_Auth() public {
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts(address(settlementSurplusAuctioneer)), true);

    // 1 contract + governor accounts
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_PostSettlementSurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(postSettlementSurplusAuctionHouse), abi.encode(_postSettlementSAHParams));
  }

  // PostSettlementAuctioneer
  function test_PostSettlementAuctioneer_Bytecode() public {
    assertEq(address(settlementSurplusAuctioneer).code, type(SettlementSurplusAuctioneer).runtimeCode);
  }

  function test_PostSettlementAuctioneer_Auth() public {
    // only governor
    assertEq(settlementSurplusAuctioneer.authorizedAccounts().length, _governorAccounts);
  }

  // Governance checks
  function test_Grant_Auth() public {
    _test_Authorizations(governor, true);
    if (delegate != address(0)) _test_Authorizations(delegate, true);
    _test_Authorizations(deployer, false);
  }

  function test_Timelock_Bytecode() public {
    assertEq(address(timelock).code, type(TimelockController).runtimeCode);
  }

  function test_Timelock_Auth() public {
    assertEq(timelock.hasRole(keccak256('PROPOSER_ROLE'), address(haiGovernor)), true);
    assertEq(timelock.hasRole(keccak256('CANCELLER_ROLE'), address(haiGovernor)), true);
    assertEq(timelock.hasRole(keccak256('EXECUTOR_ROLE'), address(0)), true);
  }

  function test_Timelock_Params() public {
    assertEq(timelock.getMinDelay(), _governorParams.timelockMinDelay);
  }

  function test_HaiGovernor_Bytecode_MANUAL_CHECK() public {
    // Not possible to check bytecode because it has immutable storage
    // Needs to be manually checked
  }

  function test_HaiGovernor_Params() public {
    assertEq(haiGovernor.votingDelay(), _governorParams.votingDelay);
    assertEq(haiGovernor.votingPeriod(), _governorParams.votingPeriod);
    assertEq(haiGovernor.proposalThreshold(), _governorParams.proposalThreshold);

    assertEq(address(haiGovernor.token()), address(protocolToken));
    assertEq(address(haiGovernor.timelock()), address(timelock));
  }

  // TokenDistributor
  function test_TokenDistributor() public {
    assertEq(address(tokenDistributor).code, type(TokenDistributor).runtimeCode);

    assertEq(protocolToken.balanceOf(address(tokenDistributor)), _tokenDistributorParams.totalClaimable);
    assertEq(protocolToken.totalSupply(), _tokenDistributorParams.totalClaimable);

    assertEq(tokenDistributor.root(), _tokenDistributorParams.root);
    assertEq(tokenDistributor.totalClaimable(), _tokenDistributorParams.totalClaimable);
    assertEq(tokenDistributor.claimPeriodStart(), _tokenDistributorParams.claimPeriodStart);
    assertEq(tokenDistributor.claimPeriodEnd(), _tokenDistributorParams.claimPeriodEnd);
  }

  function _test_Authorizations(address _target, bool _permission) internal {
    // base contracts
    assertEq(safeEngine.authorizedAccounts(_target), _permission);
    assertEq(oracleRelayer.authorizedAccounts(_target), _permission);
    assertEq(taxCollector.authorizedAccounts(_target), _permission);
    assertEq(stabilityFeeTreasury.authorizedAccounts(_target), _permission);
    assertEq(liquidationEngine.authorizedAccounts(_target), _permission);
    assertEq(accountingEngine.authorizedAccounts(_target), _permission);
    assertEq(surplusAuctionHouse.authorizedAccounts(_target), _permission);
    assertEq(debtAuctionHouse.authorizedAccounts(_target), _permission);

    // settlement
    assertEq(globalSettlement.authorizedAccounts(_target), _permission);
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts(_target), _permission);
    assertEq(settlementSurplusAuctioneer.authorizedAccounts(_target), _permission);

    // factories
    assertEq(chainlinkRelayerFactory.authorizedAccounts(_target), _permission);
    assertEq(uniV3RelayerFactory.authorizedAccounts(_target), _permission);
    assertEq(denominatedOracleFactory.authorizedAccounts(_target), _permission);
    assertEq(delayedOracleFactory.authorizedAccounts(_target), _permission);

    assertEq(collateralJoinFactory.authorizedAccounts(_target), _permission);
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(_target), _permission);

    // tokens
    assertEq(systemCoin.authorizedAccounts(_target), _permission);
    assertEq(protocolToken.authorizedAccounts(_target), _permission);

    // token adapters
    assertEq(coinJoin.authorizedAccounts(_target), _permission);

    // jobs
    assertEq(accountingJob.authorizedAccounts(_target), _permission);
    assertEq(liquidationJob.authorizedAccounts(_target), _permission);
    assertEq(oracleJob.authorizedAccounts(_target), _permission);

    // token distributor
    assertEq(tokenDistributor.authorizedAccounts(_target), _permission);
  }
}

contract E2EDeploymentMainnetTest is DeployMainnet, CommonDeploymentTest {
  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    governor = address(69);
    super.setUp();
    run();

    _governorAccounts = 1; // no delegate on production
  }

  function setupEnvironment() public override(DeployMainnet, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeployMainnet, Deploy) {
    super.setupPostEnvironment();
  }

  function test_pid_update_rate() public {
    vm.expectRevert(IPIDRateSetter.PIDRateSetter_InvalidPriceFeed.selector);
    pidRateSetter.updateRate();

    uint256 _quotePeriod = IUniV3Relayer(address(systemCoinOracle)).quotePeriod();
    skip(_quotePeriod);

    pidRateSetter.updateRate();

    vm.expectRevert(IPIDRateSetter.PIDRateSetter_RateSetterCooldown.selector);
    pidRateSetter.updateRate();

    uint256 _updateRateDelay = pidRateSetter.params().updateRateDelay;
    skip(_updateRateDelay);

    pidRateSetter.updateRate();
  }

  function test_system_coin_oracle() public {
    vm.warp(block.timestamp + 1 days);
    (uint256 _quote,) = systemCoinOracle.getResultWithValidity();

    assertEq(systemCoinOracle.symbol(), '(HAI / WETH) * (ETH / USD)');
    assertEq(1e18 / _quote, 1); // HAI = USD
  }
}

contract E2EDeploymentGoerliTest is DeployGoerli, CommonDeploymentTest {
  uint256 FORK_BLOCK = 17_000_000;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('goerli'), FORK_BLOCK);
    governor = address(69);
    super.setUp();
    run();

    // if there is a delegate, there are 2 governor accounts
    _governorAccounts = delegate == address(0) ? 1 : 2;
  }

  function setupEnvironment() public override(DeployGoerli, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeployGoerli, Deploy) {
    super.setupPostEnvironment();
  }

  function test_stones_wbtc_oracle() public {
    vm.warp(block.timestamp + 1 hours);
    delayedOracle[WBTC].updateResult();
    delayedOracle[STONES].updateResult();
    vm.warp(block.timestamp + 1 hours);
    delayedOracle[WBTC].updateResult();
    delayedOracle[STONES].updateResult();

    (uint256 _quoteStn,) = delayedOracle[STONES].getResultWithValidity(); // STN / USD
    (uint256 _quoteBtc,) = delayedOracle[WBTC].getResultWithValidity(); // BTC / USD

    assertEq(delayedOracle[STONES].symbol(), '(STN / wBTC) * (BTC / USD)');
    assertEq(_quoteBtc / _quoteStn, 1000); // 1000 STN = BTC
  }
}

/**
 * TODO: uncomment after Goerli deployment
 * contract GoerliDeploymentTest is GoerliDeployment, CommonDeploymentTest {
 *   function setUp() public {
 *     vm.createSelectFork(vm.rpcUrl('goerli'), GOERLI_DEPLOYMENT_BLOCK);
 *     _getEnvironmentParams();
 *   }
 *
 *   function test_Delegated_OP() public {
 *     assertEq(ERC20Votes(OP_OPTIMISM).delegates(address(collateralJoin[OP])), governor);
 *   }
 * }
 */
