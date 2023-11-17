// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployGoerli} from '@script/Deploy.s.sol';

import {ParamChecker, WETH, WSTETH, OP} from '@script/Params.s.sol';
import {OP_OPTIMISM} from '@script/Registry.s.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';

import '@script/Contracts.s.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
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

    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));

    // 5 contracts + 2 for each collateral type (cJoin, CAH) + 1 for governor
    assertEq(safeEngine.authorizedAccounts().length, 5 + 2 * collateralTypes.length + 1);
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

    // 2 contracts + 1 for governor
    assertEq(oracleRelayer.authorizedAccounts().length, 2 + 1);
  }

  // AccountingEngine
  function test_AccountingEngine_Bytecode() public {
    assertEq(address(accountingEngine).code, type(AccountingEngine).runtimeCode);
  }

  function test_AccountingEngine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(accountingEngine.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + 1 for governor
    assertEq(accountingEngine.authorizedAccounts().length, 2 + 1);
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

    // 1 contract + 1 for governor
    assertEq(systemCoin.authorizedAccounts().length, 1 + 1);
  }

  // ProtocolToken
  function test_ProtocolToken_Bytecode_MANUAL_CHECK() public {
    // Not possible to check bytecode because it has immutable storage
    // Needs to be manually checked
  }

  function test_ProtocolToken_Auth() public {
    assertEq(protocolToken.authorizedAccounts(address(debtAuctionHouse)), true);

    // 1 contract + 1 for governor
    assertEq(protocolToken.authorizedAccounts().length, 1 + 1);
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Bytecode() public {
    assertEq(address(surplusAuctionHouse).code, type(SurplusAuctionHouse).runtimeCode);
  }

  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), true);

    // 1 contract + 1 for governor
    assertEq(surplusAuctionHouse.authorizedAccounts().length, 1 + 1);
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

    // 1 contract + 1 for governor
    assertEq(debtAuctionHouse.authorizedAccounts().length, 1 + 1);
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

    // 2 contracts + 1 for governor
    assertEq(collateralAuctionHouseFactory.authorizedAccounts().length, 2 + 1);
  }

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), true);
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(governor)), true);

      // 1 contract (governor is authorized in the factory)
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

    // 1 contract + 1 per collateralType + 1 for governor
    assertEq(liquidationEngine.authorizedAccounts().length, 1 + collateralTypes.length + 1);
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
    assertEq(pidController.authorizedAccounts().length, 1);
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
    assertEq(pidRateSetter.authorizedAccounts().length, 1);
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
    assertEq(taxCollector.authorizedAccounts().length, 1);
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

    // 1 contract + 1 for governor
    assertEq(stabilityFeeTreasury.authorizedAccounts().length, 1 + 1);
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
    assertEq(globalSettlement.authorizedAccounts().length, 1);
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

    // 1 contract + 1 for governor
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts().length, 1 + 1);
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
    assertEq(settlementSurplusAuctioneer.authorizedAccounts().length, 1);
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

    assertEq(protocolToken.balanceOf(address(tokenDistributor)), 1_000_000e18);
    assertEq(protocolToken.totalSupply(), 1_000_000e18);

    assertEq(tokenDistributor.root(), bytes32(0));
    assertEq(tokenDistributor.totalClaimable(), 1_000_000e18);
    // assertEq claimPeriodStart
    // assertEq claimPeriodEnd
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
}

contract E2EDeploymentGoerliTest is DeployGoerli, CommonDeploymentTest {
  uint256 FORK_BLOCK = 10_000_000;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('goerli'), FORK_BLOCK);
    governor = address(69);
    super.setUp();
    run();
  }

  function setupEnvironment() public override(DeployGoerli, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeployGoerli, Deploy) {
    super.setupPostEnvironment();
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
