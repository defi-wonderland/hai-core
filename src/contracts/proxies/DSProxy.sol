pragma solidity 0.6.7;

import {DSProxyCache} from './DSProxyCache.sol';

contract DSProxy {
  DSProxyCache public cache; // global cache for contracts
  address public owner;

  function setOwner(address _owner) public {
    owner = _owner;
  }

  constructor(address _cacheAddr) public {
    setCache(_cacheAddr);
    owner = tx.origin;
  }

  receive() external payable {}

  // use the proxy to execute calldata _data on contract _code
  function execute(
    bytes memory _code,
    bytes memory _data
  ) public payable returns (address target, bytes memory response) {
    target = cache.read(_code);
    if (target == address(0)) {
      // deploy contract & store its address in cache
      target = cache.write(_code);
    }

    response = execute(target, _data);
  }

  function execute(address _target, bytes memory _data) public payable returns (bytes memory response) {
    require(_target != address(0), 'ds-proxy-target-address-required');

    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
      let size := returndatasize()

      response := mload(0x40)
      mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      mstore(response, size)
      returndatacopy(add(response, 0x20), 0, size)

      switch iszero(succeeded)
      case 1 {
        // throw if delegatecall failed
        revert(add(response, 0x20), size)
      }
    }
  }

  //set new cache
  function setCache(address _cacheAddr) public returns (bool) {
    require(_cacheAddr != address(0), 'ds-proxy-cache-address-required');
    cache = DSProxyCache(_cacheAddr); // overwrite cache
    return true;
  }
}
