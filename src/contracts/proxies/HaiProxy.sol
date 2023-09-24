// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Ownable} from '@contracts/utils/Ownable.sol';
import {Address} from '@openzeppelin/utils/Address.sol';
import {IHaiProxy} from '@interfaces/proxies/IHaiProxy.sol';

/**
 * @title  HaiProxy
 * @notice This contract is an ownable proxy to execute batched transactions in the protocol contracts
 * @dev    The proxy executes a delegate call to an Actions contract, which have the logic to execute the batched transactions
 */
contract HaiProxy is Ownable, IHaiProxy {
  using Address for address;

  // --- Init ---

  /**
   * @param  _owner The owner of the proxy contract
   */
  constructor(address _owner) Ownable(_owner) {}

  // --- Methods ---

  /// @inheritdoc IHaiProxy
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();
    _response = _target.functionDelegateCall(_data);
  }
}
