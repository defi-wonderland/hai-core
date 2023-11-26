// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AccountingEngine, IAccountingEngine} from '@contracts/AccountingEngine.sol';

contract AccountingEngineForTest is AccountingEngine {
  constructor(
    address _safeEngine,
    address _surplusAuctionHouse,
    address _debtAuctionHouse,
    address _extraSurplusReceiver,
    AccountingEngineParams memory _accEngineParams
  ) AccountingEngine(_safeEngine, _surplusAuctionHouse, _debtAuctionHouse, _extraSurplusReceiver, _accEngineParams) {}

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
