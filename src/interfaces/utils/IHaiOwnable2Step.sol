// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOwnable} from '@interfaces/utils/IOwnable.sol';

interface IHaiOwnable2Step is IOwnable {
  // --- Events ---

  /**
   * @notice Emitted when a ownership transfer is initiated
   * @param _previousOwner Address of the current owner
   * @param _newOwner Address of the new owner
   */
  event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);

  // --- Errors ---

  /// @notice Throws if an `onlyOwner` method is called by any account other than the owner
  error OwnableUnauthorizedAccount(address _sender);

  // --- Data ---

  /// @notice Address of the pending owner
  function pendingOwner() external returns (address _pendingOwner);

  // --- Admin ---

  /**
   * @notice Accept receiving the ownership of this contract, only callable by the pending owner
   */
  function acceptOwnership() external;
}
