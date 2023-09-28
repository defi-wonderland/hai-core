// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {IHaiProxy} from '@interfaces/proxies/IHaiProxy.sol';
import {IHaiProxyFactory} from '@interfaces/proxies/IHaiProxyFactory.sol';

/**
 * @title  HaiProxyFactory
 * @notice This contract is used to deploy new HaiProxy instances
 */
contract HaiProxyFactory is IHaiProxyFactory {
  // --- Data ---

  /// @inheritdoc IHaiProxyFactory
  mapping(address _proxyAddress => bool _exists) public isProxy;

  /// @inheritdoc IHaiProxyFactory
  mapping(address _owner => IHaiProxy) public proxies;

  // --- Methods ---

  /// @inheritdoc IHaiProxyFactory
  function build() external returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  /// @inheritdoc IHaiProxyFactory
  function build(address _owner) external returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  /// @notice Internal method used to deploy a new proxy instance
  function _build(address _owner) internal returns (address payable _proxy) {
    // Not allow new _proxy if the user already has one and remains being the owner
    if (proxies[_owner] != IHaiProxy(payable(address(0))) && proxies[_owner].owner() == _owner) {
      revert AlreadyHasProxy(_owner, proxies[_owner]);
    }
    _proxy = payable(address(new HaiProxy(_owner)));
    isProxy[_proxy] = true;
    proxies[_owner] = IHaiProxy(_proxy);
    emit Created(msg.sender, _owner, address(_proxy));
  }
}
