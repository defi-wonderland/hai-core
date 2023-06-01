// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {ILinkedList, LinkedList} from '@contracts/utils/LinkedList.sol';

abstract contract Base is HaiTest {
  ILinkedList public linkedList;
  address newContractAddress = label('newContractAddress');

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
  function test_Push_First() public {
    linkedList.push(newContractAddress);

    assertEq(linkedList.head(), 1);
    assertEq(linkedList.tail(), 1);
    assertEq(linkedList.size(), 1);
    assertEq(linkedList.nodes(1).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(1).next, 0);
  }

  function test_Push_First_AfterEmptiedPreviousList(uint8 _previousSize) public {
    vm.assume(_previousSize < 100);
    _loadList(_previousSize);
    _popFromList(_previousSize);

    linkedList.push(newContractAddress);
    uint256 _newKey = _previousSize + 1;
    assertEq(linkedList.head(), _newKey);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), 1);
    assertEq(linkedList.nodes(_newKey).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }

  function test_Push_WithFilledList(uint8 _previousSize) public {
    vm.assume(_previousSize < 100);
    _loadList(_previousSize);

    uint256 _newKey = _previousSize + 1;

    linkedList.push(newContractAddress);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), _newKey);
    assertEq(linkedList.nodes(_newKey).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }

  function test_Push_RandomSize(uint8 _previousSize, uint8 _removedItems) public {
    vm.assume(_previousSize < 100);
    vm.assume(_removedItems < _previousSize);
    _loadList(_previousSize);
    _popFromList(_removedItems);

    uint256 _newKey = _previousSize + 1;
    uint256 _size = _previousSize - _removedItems + 1;

    linkedList.push(newContractAddress);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), _size);
    assertEq(linkedList.nodes(_newKey).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }
}

contract Unit_LinkedList_Push_Index is Base {
  function test_Revert_EmptyList() public {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.push(newAddress(), 0);
  }

  function test_Revert_InvalidIndex(uint8 _previousSize, uint8 _index) public {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize <= _index);
    _loadList(_previousSize);

    vm.expectRevert(abi.encodeWithSelector(ILinkedList.LinkedList_InvalidIndex.selector, _index));
    linkedList.push(newAddress(), _index);
  }

  function test_Push_RandomIndex(uint8 _previousSize, uint8 _index) public {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize > _index);
    _loadList(_previousSize);

    uint256 _key = linkedList.head();
    uint256 _previousKey = 0;
    ILinkedList.Node memory _previousNodeAtIndex;

    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        _previousNodeAtIndex = linkedList.nodes(_key);
      }
      _previousKey = _key;
      _key = linkedList.nodes(_key).next;
    }

    uint256 _newKey = _previousSize + 1;
    uint256 _size = _previousSize + 1;

    linkedList.push(newContractAddress, _index);
    assertEq(linkedList.size(), _size);
    assertEq(linkedList.nodes(_newKey).contractAddress, newContractAddress);

    _key = linkedList.head();
    _previousKey = 0;
    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        assertEq(linkedList.nodes(_key).contractAddress, newContractAddress);

        if (i == 0) {
          assertEq(linkedList.head(), _newKey);
          assertEq(
            linkedList.nodes(linkedList.nodes(_newKey).next).contractAddress, _previousNodeAtIndex.contractAddress
          );
        } else {
          assertEq(linkedList.nodes(_previousKey).next, _newKey);
        }

        if (i == _size - 1) {
          assertEq(linkedList.tail(), _newKey);
          assertEq(linkedList.nodes(_newKey).next, 0);
        }
      }

      _previousKey = _key;
      _key = linkedList.nodes(_key).next;
    }
  }
}

contract Unit_LinkedList_Pop is Base {
  function test_Revert_ListEmpty() public {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.pop();
  }

  function test_Pop_RandomAmount(uint8 _previousSize, uint8 _itemsToPop) public {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize >= _itemsToPop);
    _loadList(_previousSize);

    for (uint256 i = 1; i <= _itemsToPop; i++) {
      address _expectedAddressRemoved = linkedList.nodes(linkedList.head()).contractAddress;
      uint256 _expectedNextHead = linkedList.nodes(linkedList.head()).next;
      address _removedAddress = linkedList.pop();
      assertEq(linkedList.size(), _previousSize - i);
      assertEq(_removedAddress, _expectedAddressRemoved);
      assertEq(linkedList.head(), _expectedNextHead);
    }

    if (_previousSize == _itemsToPop) {
      assertEq(linkedList.head(), 0);
      assertEq(linkedList.tail(), 0);
    }
  }
}
