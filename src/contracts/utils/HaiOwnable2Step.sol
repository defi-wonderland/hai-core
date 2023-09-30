// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IHaiOwnable2Step} from '@interfaces/utils/IHaiOwnable2Step.sol';

import {Ownable, IOwnable} from '@contracts/utils/Ownable.sol';

/**
 * @title  HaiOwnable2Step
 * @notice This abstract contract inherits Ownable and implements a two-step contract ownershup transfer
 */
abstract contract HaiOwnable2Step is Ownable, IHaiOwnable2Step {
  // --- Data ---

  /// @inheritdoc IHaiOwnable2Step
  address public pendingOwner;

  // --- Admin ---

  /// @inheritdoc IOwnable
  function setOwner(address _newOwner) public virtual override(IOwnable, Ownable) onlyOwner {
    pendingOwner = _newOwner;
    emit OwnershipTransferStarted(owner, _newOwner);
  }

  /// @inheritdoc IHaiOwnable2Step
  function acceptOwnership() public virtual {
    address _sender = msg.sender;
    if (pendingOwner != _sender) {
      revert OwnableUnauthorizedAccount(_sender);
    }
    _setOwner(_sender);
  }

  // --- Internal ---

  /// @notice Sets a new contract owner
  function _setOwner(address _newOwner) internal virtual override {
    delete pendingOwner;
    super._setOwner(_newOwner);
  }
}
