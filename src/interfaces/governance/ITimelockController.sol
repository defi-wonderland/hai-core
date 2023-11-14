// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface ITimelockController {
  struct TimelockControllerParams {
    uint256 minDelay;
    address[] proposers;
    address[] executors;
    address admin;
  }
}
