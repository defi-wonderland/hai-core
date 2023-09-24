// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IHaiProxy, HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');

  HaiProxy proxy;

  function setUp() public virtual {
    vm.startPrank(deployer);

    proxy = new HaiProxy(owner);
    label(address(proxy), 'HaiProxy');

    vm.stopPrank();
  }
}

contract Unit_HaiProxy_Execute is Base {
  address target = label('target');

  function test_execute() public {
    // We etch some arbitraty (non-reverting) bytecode
    vm.etch(target, bytes('F'));

    vm.startPrank(owner);
    proxy.execute(address(target), bytes(''));
  }

  function test_Revert_targetNoCode() public {
    vm.startPrank(owner);
    vm.expectRevert('Address: call to non-contract');

    proxy.execute(address(target), bytes(''));

    // Sanity check
    assert(target.code.length == 0);
  }

  function test_Revert_targetAddressZero() public {
    vm.startPrank(owner);
    vm.expectRevert(IHaiProxy.TargetAddressRequired.selector);

    proxy.execute(address(0), bytes(''));
  }
}
