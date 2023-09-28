// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IOwnable2Step {
  // --- Events ---
  // Can't define events since they will be defined multiple times otherwise

  // --- Errors ---

  /// @notice Throws if an `onlyOwner` method is called by any account other than the owner
  error OnlyOwner();

  // --- Data ---

  /// @notice Address of the contract owner
  function owner() external view returns (address _owner);

  /// @notice Address of the pending owner.
  function pendingOwner() external view returns (address _pendingOwner);

  // --- Admin ---

  /**
   * @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
   * @dev Can only be called by the current owner.
   * @param newOwner the address that will receive ownership (after they accept it)
   */
  function transferOwnership(address newOwner) external;

  /**
   * @notice The new owner accepts the ownership transfer.
   * @dev the sender has to be the pendingOwner
   */
  function acceptOwnership() external;
}
