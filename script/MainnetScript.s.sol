// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {Script, console} from 'forge-std/Script.sol';
import {Params, ParamChecker, WETH, OP, WSTETH} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import '@script/Registry.s.sol';

/**
 * @title  MainnetScript
 * @notice This contract is used to deploy the system on Mainnet
 * @dev    This contract imports deployed addresses from `MainnetDeployment.s.sol`
 */
contract MainnetScript is MainnetDeployment, Common, Script {
  function setUp() public virtual {}

  /**
   * @notice This script is left as an example on how to use MainnetScript contract
   * @dev    This script is executed with `yarn script:mainnet` command
   */
  function run() public {
    _getEnvironmentParams();
    
    // timelock with permissions
    vm.startPrank(0xd68e7D20008a223dD48A6076AAf5EDd4fe80a899);

    IBaseOracle _wstethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, 24 hours);

    IBaseOracle _wstethUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: IBaseOracle(0xF808Bb8264459F5e04a9870D4473b36229126943),
      _inverted: false
    });

    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, 1 hours);

    // Script goes here
    vm.stopPrank();
  }
}
