// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {ILinkedList, LinkedList} from '@contracts/utils/LinkedList.sol';

abstract contract Base is HaiTest {
  ILinkedList public linkedList;

  function setUp() public virtual {
    linkedList = new LinkedList();
  }

  function _loadList(uint256 _size) internal {
    for (uint256 i = 0; i < _size; i++) {
      linkedList.push(newAddress());
    }
  }

  function _popFromList(uint256 _popNumber) internal {
    for (uint256 i = 0; i < _popNumber; i++) {
      linkedList.pop();
    }
  }
}

contract Unit_LinkedList_Push is Base {
  function test_Push_FirstElement(address _contractAddress) public {
    linkedList.push(_contractAddress);

    assertEq(linkedList.head(), 1);
    assertEq(linkedList.tail(), 1);
    assertEq(linkedList.size(), 1);
    assertEq(linkedList.nodes(1).contractAddress, _contractAddress);
    assertEq(linkedList.nodes(1).next, 0);
  }

  function test_Push_FirstElement_AfterEmptiedPreviousList(uint48 _previousSize, address _contractAddress) public {
    vm.assume(_previousSize < 100);
    _loadList(_previousSize);
    _popFromList(_previousSize);

    linkedList.push(_contractAddress);
    uint256 _newKey = _previousSize + 1;
    assertEq(linkedList.head(), _newKey);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), 1);
    assertEq(linkedList.nodes(_newKey).contractAddress, _contractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }

  function test_Push_ElementWithFilledList(uint48 _previousSize, address _contractAddress) public {
    vm.assume(_previousSize < 100);
    _loadList(_previousSize);

    linkedList.push(_contractAddress);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), _newKey);
    assertEq(linkedList.nodes(_newKey).contractAddress, _contractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }
}
