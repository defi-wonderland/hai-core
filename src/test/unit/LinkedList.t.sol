// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {ILinkedList, LinkedList} from '@contracts/utils/LinkedList.sol';

abstract contract Base is HaiTest {
  ILinkedList public linkedList;
  address newContractAddress = label('newContractAddress');
  address placeHolderAddress = label('placeHolderAddress');
  address deployer = label('deployer');

  function setUp() public virtual {
    vm.prank(deployer);
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

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }
}

contract Unit_LinkedList_Push is Base {
  function test_Push_First() public authorized {
    linkedList.push(newContractAddress);

    assertEq(linkedList.head(), 1);
    assertEq(linkedList.tail(), 1);
    assertEq(linkedList.size(), 1);
    assertEq(linkedList.nodes(1).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(1).next, 0);
  }

  function test_Push_First_AfterEmptiedPreviousList(uint8 _previousSize) public authorized {
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

  function test_Push_WithFilledList(uint8 _previousSize) public authorized {
    vm.assume(_previousSize < 100);
    _loadList(_previousSize);

    uint256 _newKey = _previousSize + 1;

    linkedList.push(newContractAddress);
    assertEq(linkedList.tail(), _newKey);
    assertEq(linkedList.size(), _newKey);
    assertEq(linkedList.nodes(_newKey).contractAddress, newContractAddress);
    assertEq(linkedList.nodes(_newKey).next, 0);
  }

  function test_Push_RandomSize(uint8 _previousSize, uint8 _removedItems) public authorized {
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
  function test_Revert_EmptyList() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.push(newAddress(), 0);
  }

  function test_Revert_InvalidIndex(uint8 _previousSize, uint8 _index) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize <= _index);
    _loadList(_previousSize);

    vm.expectRevert(abi.encodeWithSelector(ILinkedList.LinkedList_InvalidIndex.selector, _index));
    linkedList.push(newAddress(), _index);
  }

  function test_Push_RandomIndex(uint8 _previousSize, uint8 _index) public authorized {
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
    assertEq(linkedList.nodes(linkedList.nodes(_newKey).next).contractAddress, _previousNodeAtIndex.contractAddress);
    if (_index == 0) {
      assertEq(linkedList.head(), _newKey);
    } else {
      assertEq(linkedList.nodes(_index).next, _newKey);
    }
  }
}

contract Unit_LinkedList_Pop is Base {
  function test_Revert_ListEmpty() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.pop();
  }

  function test_Pop_RandomAmount(uint8 _previousSize, uint8 _itemsToPop) public authorized {
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
      assertEq(linkedList.nodes(i).contractAddress, address(0));
      assertEq(linkedList.nodes(i).next, 0);
    }

    if (_previousSize == _itemsToPop) {
      assertEq(linkedList.head(), 0);
      assertEq(linkedList.tail(), 0);
    }
  }
}

contract Unit_LinkedList_Remove_ContractAddress is Base {
  function test_Revert_ListEmpty() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.remove(newContractAddress);
  }

  function test_Remove_At_RandomPosition(uint8 _previousSize, uint8 _randomPosition) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize > _randomPosition);

    for (uint256 i = 0; i < _previousSize; i++) {
      if (i == _randomPosition) {
        linkedList.push(newContractAddress);
      } else {
        linkedList.push(newAddress());
      }
    }
    bool _success = linkedList.remove(newContractAddress);

    assertTrue(_success);
    assertEq(linkedList.size(), _previousSize - 1);
    assertEq(linkedList.nodes(_randomPosition + 1).contractAddress, address(0));
    assertEq(linkedList.nodes(_randomPosition + 1).next, 0);

    if (_previousSize == 1) {
      assertEq(linkedList.head(), 0);
      assertEq(linkedList.tail(), 0);
    } else {
      if (_randomPosition == 0) {
        assertEq(linkedList.head(), 2);
      } else if (_randomPosition == _previousSize - 1) {
        assertEq(linkedList.tail(), _previousSize - 1);
      } else {
        assertEq(linkedList.nodes(_randomPosition).next, _randomPosition + 2);
      }
    }
  }

  function test_Return_False_ContractNotFound(uint8 _previousSize) public  authorized{
    vm.assume(_previousSize > 0 && _previousSize < 100);
    _loadList(_previousSize);
    bool _success = linkedList.remove(newContractAddress);

    assertFalse(_success);
    assertEq(linkedList.size(), _previousSize);
  }
}

contract Unit_LinkedList_Remove_Index is Base {
  function test_Revert_ListEmpty() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.remove(0);
  }

  function test_Revert_InvalidIndex(uint8 _size, uint8 _index) public authorized {
    vm.assume(_size > 0 && _size < 100);
    vm.assume(_index >= _size);
    _loadList(_size);

    vm.expectRevert(abi.encodeWithSelector(ILinkedList.LinkedList_InvalidIndex.selector, _index));
    linkedList.remove(_index);
  }

  function test_Remove_At_RandomPosition123(uint8 _previousSize, uint8 _randomPosition) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize > _randomPosition);

    for (uint256 i = 0; i < _previousSize; i++) {
      if (i == _randomPosition) {
        linkedList.push(newContractAddress);
      } else {
        linkedList.push(newAddress());
      }
    }
    (bool _success, address _removedAddress) = linkedList.remove(_randomPosition);

    assertTrue(_success);
    assertEq(_removedAddress, newContractAddress);
    assertEq(linkedList.size(), _previousSize - 1);
    assertEq(linkedList.nodes(_randomPosition + 1).contractAddress, address(0));
    assertEq(linkedList.nodes(_randomPosition + 1).next, 0);

    if (_previousSize == 1) {
      assertEq(linkedList.head(), 0);
      assertEq(linkedList.tail(), 0);
    } else {
      if (_randomPosition == 0) {
        assertEq(linkedList.head(), 2);
      } else if (_randomPosition == _previousSize - 1) {
        assertEq(linkedList.tail(), _previousSize - 1);
      } else {
        assertEq(linkedList.nodes(_randomPosition).next, _randomPosition + 2);
      }
    }
  }
}

contract Unit_LinkedList_Replace_Index is Base {
  function test_Revert_ListEmpty() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.replace(0, newContractAddress);
  }

  function test_Revert_InvalidIndex(uint8 _size, uint8 _index) public authorized {
    vm.assume(_size > 0 && _size < 100);
    vm.assume(_index >= _size);
    _loadList(_size);

    vm.expectRevert(abi.encodeWithSelector(ILinkedList.LinkedList_InvalidIndex.selector, _index));
    linkedList.replace(_index, newContractAddress);
  }

  function test_Replace_At_RandomPosition(uint8 _previousSize, uint8 _randomPosition) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize > _randomPosition);

    for (uint256 i = 0; i < _previousSize; i++) {
      if (i == _randomPosition) {
        linkedList.push(placeHolderAddress);
      } else {
        linkedList.push(newAddress());
      }
    }

    address _removedAddress = linkedList.replace(_randomPosition, newContractAddress);

    assertEq(_removedAddress, placeHolderAddress);
    assertEq(linkedList.size(), _previousSize);
    assertEq(linkedList.nodes(_randomPosition + 1).contractAddress, newContractAddress);
  }
}

contract Unit_LinkedList_Replace_ContractAddress is Base {
  function test_Revert_ListEmpty() public authorized {
    vm.expectRevert(ILinkedList.LinkedList_EmptyList.selector);
    linkedList.replace(placeHolderAddress, newContractAddress);
  }

  function test_Replace_At_RandomPosition(uint8 _previousSize, uint8 _randomPosition) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    vm.assume(_previousSize > _randomPosition);

    for (uint256 i = 0; i < _previousSize; i++) {
      if (i == _randomPosition) {
        linkedList.push(placeHolderAddress);
      } else {
        linkedList.push(newAddress());
      }
    }

    bool _success = linkedList.replace(placeHolderAddress, newContractAddress);

    assertTrue(_success);
    assertEq(linkedList.size(), _previousSize);
    assertEq(linkedList.nodes(_randomPosition + 1).contractAddress, newContractAddress);
  }

  function test_Return_False_ContractNotFound(uint8 _previousSize) public authorized {
    vm.assume(_previousSize > 0 && _previousSize < 100);
    _loadList(_previousSize);
    bool _success = linkedList.replace(placeHolderAddress, newContractAddress);

    assertFalse(_success);
    assertEq(linkedList.size(), _previousSize);
  }
}
