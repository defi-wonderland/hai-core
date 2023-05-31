// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ILinkedList} from '@interfaces/utils/ILinkedList.sol';

contract LinkedList is ILinkedList {
  // Valid keys will always start from 1, should never be confused with indexes which are the position in the list and are calculated
  uint256 public head;
  uint256 public tail;
  uint256 public size;

  mapping(uint256 => Node) internal _nodes;

  function nodes(uint256 _key) external view returns (Node memory _node) {
    return _nodes[_key];
  }

  function push(address _contractAddress) external returns (uint256 _index) {
    // The elements are added at the end of the list
    Node memory _node = Node({
      contractAddress: _contractAddress,
      next: 0 // 0 means that there is no next element because it's the end of the list
    });
    ++size;
    // adding element at the mapping
    _nodes[size] = _node;
    if (size == 0) {
      // head should be the new node
      head = size;
    } else {
      // updates the old tail
      _nodes[tail].next = size;
    }

    // updates the tail
    tail = size;

    return size;
  }

  function push(address _contractAddress, uint256 _index) external returns (bool success) {
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    uint256 _previousKey = 0;
    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        // reusable block between push functions but letting it for clarity of the spike
        // the element is the head
        Node memory _node = Node({contractAddress: _contractAddress, next: _key});
        ++size;
        // adding element at the mapping
        _nodes[size] = _node;
        if (_previousKey == 0) {
          // head should be the new node
          head = size;
        } else {
          // updates the previous element of the index
          _nodes[_previousKey].next = size;

          if (i == size - 1) {
            // updates the tail
            tail = size;
          }
        }

        return true;
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
    }
  }

  function remove(address _contractAddress) external returns (bool _success) {
    if (size == 0) revert LinkedList_EmptyList();
    uint256 _key = head;
    uint256 _previousKey = 0;
    while (_key != 0) {
      if (_nodes[_key].contractAddress == _contractAddress) {
        // The element to remove was found
        if (_previousKey == 0) {
          // reusable block between remove functions but letting it for clarity of the spike
          // the element to remove is the head
          head = _nodes[_key].next;
        } else {
          // the element to remove is not the head
          _nodes[_previousKey].next = _nodes[_key].next;
        }
        delete _nodes[_key];
        --size;
        return true;
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
    }
    return false;
  }

  function remove(uint256 _index) external returns (bool _success, address _contractAddress) {
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    uint256 _previousKey = 0;
    for (uint256 i = 0; i < _index; i++) {
      if (i == _index) {
        if (_previousKey == 0) {
          // the element to remove is the head
          head = _nodes[_key].next;
        } else {
          // the element to remove is not the head
          _nodes[_previousKey].next = _nodes[_key].next;
        }
        _contractAddress = _nodes[_key].contractAddress;
        delete _nodes[_key];
        --size;
        return (true, _contractAddress);
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
    }
    return (false, address(0));
  }

  function replace(address _contractAddress, uint256 _index) external returns (bool _success, address _removedAddress) {
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    for (uint256 i = 0; i < _index; i++) {
      if (i == _index) {
        _removedAddress = _nodes[_key].contractAddress;
        _nodes[_key].contractAddress = _contractAddress;
        return (true, _removedAddress);
      }
      _key = _nodes[_key].next;
    }
    return (false, address(0));
  }

  function replace(address _contractAddress, address _replacedAddress) external returns (bool _success, uint256 _index) {
    if (size == 0) revert LinkedList_EmptyList();
    uint256 _key = head;
    uint256 _previousKey = 0;
    while (_key != 0) {
      if (_nodes[_key].contractAddress == _replacedAddress) {
        _nodes[_key].contractAddress = _contractAddress;
        return (true, _index);
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
      ++_index;
    }
    return (false, 0);
  }
}
