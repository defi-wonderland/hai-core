// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {Contracts, OracleForTest} from '@script/Contracts.s.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {Math} from '../../contracts/utils/Math.sol';

uint256 constant YEAR = 365 days;
uint256 constant RAY = 1e27;
uint256 constant RAD_DELTA = 0.0001e45;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 HAI

contract E2ETest is PRBTest, Contracts {
  Deploy deployment;
  address deployer;

  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  uint256 auctionId;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();
    deployer = deployment.deployer();

    vm.label(deployer, 'Deployer');
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(carol, 'Carol');
    vm.label(dave, 'Dave');

    safeEngine = deployment.safeEngine();
    accountingEngine = deployment.accountingEngine();
    taxCollector = deployment.taxCollector();
    debtAuctionHouse = deployment.debtAuctionHouse();
    surplusAuctionHouse = deployment.surplusAuctionHouse();
    liquidationEngine = deployment.liquidationEngine();
    oracleRelayer = deployment.oracleRelayer();
    coinJoin = deployment.coinJoin();
    coin = deployment.coin();
    protocolToken = deployment.protocolToken();

    ethJoin = deployment.ethJoin();
    ethOracle = deployment.ethOracle();
    collateralAuctionHouse = deployment.ethCollateralAuctionHouse();

    globalSettlement = deployment.globalSettlement();
  }

  function test_open_safe() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(ETH_A, address(this));
    assertEq(_generatedDebt, DEBT);
    assertEq(_lockedCollateral, COLLAT);
  }

  function test_exit_join() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    safeEngine.approveSAFEModification(address(coinJoin));
    coinJoin.exit(address(this), DEBT);
    assertEq(coin.balanceOf(address(this)), DEBT);
  }

  function test_stability_fee() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(ETH_A);

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertAlmostEq(_globalDebtAfterTax, Math.wmul(DEBT, TEST_ETH_A_SF_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins = safeEngine.coinBalance(address(accountingEngine));
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }

  function test_liquidation() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    ethOracle.setPriceAndValidity(TEST_ETH_PRICE_DROP, true);
    oracleRelayer.updateCollateralPrice(ETH_A);

    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(ETH_A, address(this));
    assertEq(_lockedCollateral, 0);
    assertEq(_generatedDebt, 0);
  }

  function test_liquidation_by_price_drop() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    // NOTE: LVT for price = 1000 is 50%
    _setCollateralPrice(ETH_A, 675e18); // LVT = 74,0% = 1/1.35

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    _setCollateralPrice(ETH_A, 674e18); // LVT = 74,1% > 1/1.35
    liquidationEngine.liquidateSAFE(ETH_A, address(this));
  }

  function test_liquidation_by_fees() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));

    _collectFees(8 * YEAR); // 1.05^8 = 148%

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    _collectFees(YEAR); // 1.05^9 = 153%
    liquidationEngine.liquidateSAFE(ETH_A, address(this));
  }

  function test_collateral_auction() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    uint256 _discount = collateralAuctionHouse.minDiscount();
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse.getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    collateralAuctionHouse.buyCollateral(1, _amountToBid);

    // NOTE: bids(1) is deleted
    (uint256 _amountToSell,,,,,,,,) = collateralAuctionHouse.bids(1);
    assertEq(_amountToSell, 0);
  }

  function test_collateral_auction_partial() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    uint256 _discount = collateralAuctionHouse.minDiscount();
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse.getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT / 2);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    collateralAuctionHouse.buyCollateral(1, _amountToBid);

    // NOTE: bids(1) is NOT deleted
    (uint256 _amountToSell,,,,,,,,) = collateralAuctionHouse.bids(1);
    assertGt(_amountToSell, 0);
  }

  function test_debt_auction() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt();

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(1);
    assertEq(_bidAmount, BID_AUCTION_SIZE);
    assertEq(_amountToSell, INITIAL_DEBT_AUCTION_MINTED_TOKENS);
    assertEq(_highBidder, address(accountingEngine));

    uint256 _deltaCoinBalance = safeEngine.coinBalance(address(this));
    uint256 _bidDecrease = debtAuctionHouse.bidDecrease();
    uint256 _tokenAmount = Math.wdiv(INITIAL_DEBT_AUCTION_MINTED_TOKENS, _bidDecrease);

    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.decreaseSoldAmount(1, _tokenAmount, BID_AUCTION_SIZE);

    (_bidAmount, _amountToSell, _highBidder,,) = debtAuctionHouse.bids(1);
    assertEq(_bidAmount, BID_AUCTION_SIZE);
    assertEq(_amountToSell, _tokenAmount);
    assertEq(_highBidder, address(this));

    vm.warp(_auctionDeadline);
    debtAuctionHouse.settleAuction(1);

    _deltaCoinBalance -= safeEngine.coinBalance(address(this));
    assertEq(_deltaCoinBalance, BID_AUCTION_SIZE);
    assertEq(protocolToken.balanceOf(address(this)), _tokenAmount);
  }

  function test_surplus_auction() public {
    _openSafe(address(this), int256(COLLAT), int256(DEBT));
    uint256 INITIAL_BID = 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), INITIAL_BID);

    // generate surplus
    _collectFees(10 * YEAR);

    accountingEngine.auctionSurplus();

    uint256 _delay = surplusAuctionHouse.totalAuctionLength();
    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(1);
    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, SURPLUS_AUCTION_SIZE);
    assertEq(_highBidder, address(accountingEngine));
    assertEq(_auctionDeadline, block.timestamp + _delay);

    protocolToken.approve(address(surplusAuctionHouse), INITIAL_BID);
    surplusAuctionHouse.increaseBidSize(1, SURPLUS_AUCTION_SIZE, INITIAL_BID);

    (_bidAmount, _amountToSell, _highBidder,,) = surplusAuctionHouse.bids(1);
    assertEq(_bidAmount, INITIAL_BID);
    assertEq(_highBidder, address(this));

    vm.warp(_auctionDeadline);

    assertEq(protocolToken.totalSupply(), INITIAL_BID);
    surplusAuctionHouse.settleAuction(1);
    assertEq(protocolToken.totalSupply(), INITIAL_BID / 2); // 50% of the bid is burned
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), INITIAL_BID / 2); // 50% is sent to the receiver
    assertEq(protocolToken.balanceOf(address(this)), 0);
  }

  function test_global_settlement() public {
    _openSafe(alice, int256(COLLAT), int256(DEBT));
    _openSafe(bob, int256(COLLAT), int256(DEBT));
    _openSafe(carol, int256(COLLAT), int256(DEBT));

    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP); // price 1 ETH = 100 HAI
    liquidationEngine.liquidateSAFE(ETH_A, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt(); // active debt auction

    liquidationEngine.liquidateSAFE(ETH_A, bob); // active collateral auction

    _collectFees(50 * YEAR);
    accountingEngine.auctionSurplus(); // active surplus auction

    // NOTE: why DEBT/10 not-safe? (price dropped to 1/10)
    _openSafe(dave, int256(COLLAT), int256(DEBT / 100)); // active healthy safe

    vm.prank(deployer);
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType(ETH_A);

    // alice has a safe liquidated for price drop (active collateral auction)
    // bob has a safe liquidated for price drop (active debt auction)
    // carol has a safe that provides surplus (active surplus auction)
    // dave has a healthy active safe
  }

  function _openSafe(address _user, int256 _deltaCollat, int256 _deltaDebt) internal {
    vm.startPrank(_user);
    vm.deal(_user, 1000e18);
    ethJoin.join{value: 100e18}(_user); // 100 ETH

    safeEngine.approveSAFEModification(address(ethJoin));

    safeEngine.modifySAFECollateralization({
      collateralType: ETH_A,
      safe: _user,
      collateralSource: _user,
      debtDestination: _user,
      deltaCollateral: _deltaCollat,
      deltaDebt: _deltaDebt
    });

    vm.stopPrank();
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    (IOracle _oracle,,) = oracleRelayer.collateralTypes(_collateral);
    OracleForTest(address(_oracle)).setPriceAndValidity(_price, true);
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(ETH_A);
  }
}
