// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  ERC20VotesUpgradeable,
  ERC20PermitUpgradeable,
  ERC20Upgradeable
} from '@openzeppelin-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import {AuthorizableUpgradeable} from '@contracts/utils/AuthorizableUpgradeable.sol';

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

/**
 * @title  ProtocolToken
 * @notice This contract represents the protocol ERC20Votes token to be used for governance purposes
 */
contract ProtocolToken is ERC20VotesUpgradeable, AuthorizableUpgradeable, IProtocolToken {
  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   */
  function initialize(string memory _name, string memory _symbol) external initializer {
    __ERC20_init(_name, _symbol);
    __ERC20Permit_init(_name);
    __authorizable_init(msg.sender);
  }

  // --- Methods ---

  /// @inheritdoc IProtocolToken
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  /// @inheritdoc IProtocolToken
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  // --- Overrides ---

  // Uncomment when upgrading to OZ 5.x
  // function _update(address _from, address _to, uint256 _value) internal override(ERC20, ERC20Votes) {
  //   super._update(_from, _to, _value);
  // }

  // Uncomment when upgrading to OZ 5.x
  // function nonces(address _owner) public view override(ERC20Permit, IERC20Permit, Nonces) returns (uint256 _nonce) {
  //   return super.nonces(_owner);
  // }
}
