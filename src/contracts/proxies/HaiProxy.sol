// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Ownable2Step, Ownable} from '@openzeppelin/access/Ownable2Step.sol';
import {IHaiProxy, IOwnable2Step} from '@interfaces/proxies/IHaiProxy.sol';

/**
 * @title  HaiProxy
 * @notice This contract is an ownable proxy to execute batched transactions in the protocol contracts
 * @dev    The proxy executes a delegate call to an Actions contract, which have the logic to execute the batched transactions
 */
contract HaiProxy is Ownable2Step, IHaiProxy {
  // --- Init ---

  /**
   * @param  _owner The owner of the proxy contract
   */
  constructor(address _owner) {
    _transferOwnership(_owner);
  }

  // --- Methods ---

  /// @inheritdoc IHaiProxy
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
  }

  // --- Overrides ---
  function acceptOwnership() public virtual override(IOwnable2Step, Ownable2Step) {
    return Ownable2Step.acceptOwnership();
  }

  function owner() public view virtual override(IOwnable2Step, Ownable) returns (address) {
    return Ownable.owner();
  }

  function transferOwnership(address newOwner) public virtual override(IOwnable2Step, Ownable2Step) {
    return Ownable2Step.transferOwnership(newOwner);
  }

  function pendingOwner() public view virtual override(IOwnable2Step, Ownable2Step) returns (address) {
    return Ownable2Step.pendingOwner();
  }
}
