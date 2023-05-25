pragma solidity 0.6.7;

import {DSProxyCache} from './DSProxyCache.sol';
import {DSProxy} from './DSProxy.sol';

contract DSProxyFactory {
  event Created(address indexed sender, address indexed owner, address proxy, address cache);

  mapping(address => bool) public isProxy;
  DSProxyCache public cache;

  constructor() public {
    cache = new DSProxyCache();
  }

  // deploys a new proxy instance
  // sets owner of proxy to caller
  function build() public returns (address payable proxy) {
    proxy = build(msg.sender);
  }

  // deploys a new proxy instance
  // sets custom owner of proxy
  function build(address owner) public returns (address payable proxy) {
    proxy = payable(address(new DSProxy(payable(address(cache)))));
    emit Created(msg.sender, owner, address(proxy), address(cache));
    DSProxy(proxy).setOwner(owner);
    isProxy[proxy] = true;
  }
}
