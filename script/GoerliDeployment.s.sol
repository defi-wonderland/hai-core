// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  // NOTE: The last significant change in the Goerli deployment, to be used in the test scenarios
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 17_405_091;

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    governor = 0xF33D1C467C89fbf3707Ed06ccE1F4dc9Ac67fcdd;
    delegatee[OP] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = IERC20Metadata(0xce189bABB8ef4D6C8aCEECe15041B07aD285525c);
    collateral[STONES] = IERC20Metadata(0x0769cf3aB738805feEc6446671f29b629a6Eb007);
    collateral[TOTEM] = IERC20Metadata(0xea0E4f32286B220426924AD8bAc34011aC398CD5);

    systemCoin = SystemCoin(0x8b3ABC94912E2c0AdED158a8a1a4625b059B7013);
    protocolToken = ProtocolToken(0x3782a19B5dE99AC4bf2dBfA8696eFeE03b852ad7);

    // --- base contracts ---
    safeEngine = SAFEEngine(0xa556E818D0267972f26875E438B876E5eA899DE5);
    oracleRelayer = OracleRelayer(0x71F6Ea7e58BF7865c884e653ee267F33e25A1bDB);
    surplusAuctionHouse = SurplusAuctionHouse(0xa4Be6131fCe3aeEb4eec37B9CBe308E778BD0Ca5);
    debtAuctionHouse = DebtAuctionHouse(0x79Ca8dBDc7B6d4DC74De1D395BC5115b97B158b9);
    accountingEngine = AccountingEngine(0x139831976569dc9EA6e6ed3DBcE1552DdD23d0a2);
    liquidationEngine = LiquidationEngine(0xF4FEE3168C6893cfb3c88b955db3B7176138AC3a);
    coinJoin = CoinJoin(0x2C168911825c73Ebe7bbaa8e9392a3Fd6110572E);
    taxCollector = TaxCollector(0x7DFDBA00D9268f4BbcDDA05d20D2352BcCcE3B73);
    stabilityFeeTreasury = StabilityFeeTreasury(0xe1E5984d9d43B88F57ef0958A10804c2E3930d2b);
    pidController = PIDController(0x859aeBC5E08e628D87151bF6751A51A41E1e6c65);
    pidRateSetter = PIDRateSetter(0x68F4088d742cb05305F44FBD2e1475A9783965fb);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x2a9668714F0fD8C64C5CD7Aa609657D5c2e2068b);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xdFCD7C54C540bFA822f5426C3e31283A755b1d8d);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x19CfDb0a674F8C35C8fDC23FD6951B0b0C2F814f);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x888179D6aBd0084623d072bf165a0EB2fdAfFaB9);
    uniV3RelayerFactory = UniV3RelayerFactory(0x3564AbBDE84BA9Eab4FbA740f8A7E2DD4Fc62Ece);
    denominatedOracleFactory = DenominatedOracleFactory(0x77F03A22ee1D89Bcc9f02B1C0b5108B48735f178);
    delayedOracleFactory = DelayedOracleFactory(0x46F1d965cEec12ac0f60ff297392379035B3f515);

    collateralJoinFactory = CollateralJoinFactory(0xc3769dD10048507C8a87bdfCD3b7de0aB42740d9);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x79843bc4EEaF06C1bAdF6Dd6812D919075dF1750);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x696d892DfA1E03D31B01a65d2D9893aCACfBe772);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0xcD94C23215ac0dbCE30B949b6fB38F23fD79Ea71);

    collateralJoin[OP] = CollateralJoin(0x6Ea34cDFCf7fA87630B462CbBBD92E014B8DD7e1);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x8D693413400dA88f55FAB8771B93b0Ab173ecC09);

    collateralJoin[WBTC] = CollateralJoin(0x61CCef8AEf3be98943056CFf3d89361663E1881D);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0xAA6562cC1Bd46b5ed991e3a52b5d3226FB42EdFa);

    collateralJoin[STONES] = CollateralJoin(0xf9bE2f75AF6a5b1Ae0A3DA4A2a02259748B121A1);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xED1a61e40354D6922Ef55517cB47eB42DBCA3642);

    collateralJoin[TOTEM] = CollateralJoin(0x9E789a6989bd937f6901fEB334cB50FC0bE1d5ff);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x1Ba14983E32D566aB8C87f1FbBCF0e7FD502b468);

    // --- jobs ---
    accountingJob = AccountingJob(0xD06E74D1Ca748961c5d2159f7E80b9B0F3D159e9);
    liquidationJob = LiquidationJob(0x1eEe34b42a6Fd0A547D4187fC969993FD5c9566E);
    oracleJob = OracleJob(0xE12F549F0040853413D04bD9293821102b7d0141);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x4d91C8DD16971A7Ff754C7dDEeb79541aa2e5Ae8);
    safeManager = HaiSafeManager(0xFAD5b78d71304824F5e63F22d0C55a41fe5fb421);

    basicActions = BasicActions(0x43F4Faf76A70278DFc956B8c7a3347D451545b1f);
    debtBidActions = DebtBidActions(0x3c690f1A6b5EA9379437293Af814C24D2d28FEC7);
    surplusBidActions = SurplusBidActions(0xa4aB2bDF232CFdC3c12b81B3d8eF01370b299e43);
    collateralBidActions = CollateralBidActions(0x7bbDC53B7afd090E9CCED81aD8f5e5aA716981F4);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x0fa711A2F535B949C11FD6Ebd2d64a1f8103Ef33);
    globalSettlementActions = GlobalSettlementActions(0xf4d4a68273205c6e0a34c7D83bab2D93cB84Bcd4);
    rewardedActions = RewardedActions(0x54b469D98Df463b5df22CA872EAb74e56c8Ab8D7);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x764082E1C0B2D117B422935Bfe5b715A2f85B37f);
    delayedOracle[WETH] = IDelayedOracle(0xAfeAbb8ab930fD93ad32A749a02C2D5bCfFe55ac);
    delayedOracle[OP] = IDelayedOracle(0x8F60bcb730aA56736c709ADc24A178BE02c0070E);
    delayedOracle[WBTC] = IDelayedOracle(0x5eCd37849DB41d8F97181c371Ec1fc38b3c2d2d0);
    delayedOracle[STONES] = IDelayedOracle(0x0F8B8744793a889Fa940454d4011B6057d927C76);
    delayedOracle[TOTEM] = IDelayedOracle(0xaD7eb50C94B443f278715A85a8C39415bD2835c9);

    // --- governance ---
    timelock = TimelockController(payable(0xF33D1C467C89fbf3707Ed06ccE1F4dc9Ac67fcdd));
    haiGovernor = HaiGovernor(payable(0x46E421874d55b85B144b3b531EE73d973c915f65));
    tokenDistributor = TokenDistributor(0x489FEb7c82d9515455F62226A0c04aCe293B0693);
  }
}
