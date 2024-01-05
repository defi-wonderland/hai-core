// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IProtocolToken is IERC20Metadata, IERC20Permit, IVotes, IAuthorizable {
  // --- Errors ---

  /// @notice Throws when trying to pause the token a second time
  error ProtocolToken_NotPausable();

  // --- Data ---

  /**
   * @notice Pausability status of the token
   * @return _notPausable Whether the token is pausable or not
   */
  function notPausable() external view returns (bool _notPausable);

  // --- Methods ---

  /**
   * @notice Mint an amount of tokens to an account
   * @param _account Address of the account to mint tokens to
   * @param _amount Amount of tokens to mint [wad]
   * @dev   Only authorized addresses can mint tokens
   */
  function mint(address _account, uint256 _amount) external;

  /**
   * @notice Burn an amount of tokens from the sender
   * @param _amount Amount of tokens to burn [wad]
   */
  function burn(uint256 _amount) external;

  /**
   * @notice Pause the token transfers, minting and burning
   * @dev    Only authorized addresses can pause the token
   */
  function pause() external;

  /**
   * @notice Unpause the token transfers, minting and burning
   * @dev    Only authorized addresses can unpause the token
   */
  function unpause() external;
}
