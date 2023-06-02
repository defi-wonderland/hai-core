// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ILinkedList} from '@interfaces/utils/ILinkedList.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract LinkedList is Authorizable, ILinkedList {
  
  uint256 public head;
  uint256 public tail;
  uint256 public size;
  // Valid keys will always start from 1, should never be confused with indexes which are the position in the list and are calculated
  // a key will never be repeated in the LinkedList contract lifetime
  uint256 private _lastKeyGenerated;

  mapping(uint256 => Node) internal _nodes;

  constructor() Authorizable(msg.sender) {}

  function nodes(uint256 _key) external view returns (Node memory _node) {
    return _nodes[_key];
  }

  function push(address _contractAddress) external isAuthorized returns (uint256 _index) {
    // The elements are added at the end of the list
    Node memory _node = Node({
      contractAddress: _contractAddress,
      next: 0 // 0 means that there is no next element because it's the end of the list
    });
    ++_lastKeyGenerated;
    // adding element at the mapping
    _nodes[_lastKeyGenerated] = _node;
    if (size == 0) {
      // head should be the new node
      head = _lastKeyGenerated;
    } else {
      // updates the old tail
      _nodes[tail].next = _lastKeyGenerated;
    }

    ++size;
    // updates the tail
    tail = _lastKeyGenerated;

    return size;
  }

  function push(address _contractAddress, uint256 _index) external isAuthorized returns (bool success) {
    if (size == 0) revert LinkedList_EmptyList();
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    uint256 _previousKey = 0;
    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        // reusable block between push functions but letting it for clarity of the spike
        // the element is the head
        Node memory _node = Node({contractAddress: _contractAddress, next: _key});
        ++_lastKeyGenerated;
        // adding element at the mapping
        _nodes[_lastKeyGenerated] = _node;
        if (_previousKey == 0) {
          // head should be the new node
          head = _lastKeyGenerated;
        } else {
          // updates the previous element of the index
          _nodes[_previousKey].next = _lastKeyGenerated;
        }

        ++size;
        return true;
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
    }
  }

  function pop() external isAuthorized returns (address _contractAddress) {
    if (size == 0) revert LinkedList_EmptyList();
    Node memory _node = _nodes[head];
    delete _nodes[head];
    head = _node.next;
    --size;
    if (size == 0) {
      // if the list is empty, the tail should be 0
      tail = 0;
    }
    return _node.contractAddress;
  }

  function remove(address _contractAddress) external isAuthorized returns (bool _success) {
    if (size == 0) revert LinkedList_EmptyList();
    uint256 _key = head;
    uint256 _previousKey = 0;
    while (_key != 0) {
      if (_nodes[_key].contractAddress == _contractAddress) {
        // The element to remove was found
        if (_key == tail) {
          // updates the tail
          tail = _previousKey;
        }
        if (_key == head) {
          // updates the head
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
  }

  function remove(uint256 _index) external isAuthorized returns (bool _success, address _contractAddress) {
    if (size == 0) revert LinkedList_EmptyList();
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    uint256 _previousKey = 0;
    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        if (_key == tail) {
          // updates the tail
          tail = _previousKey;
        }
        if (_key == head) {
          // updates the head
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
  }

  function replace(uint256 _index, address _contractAddress) external isAuthorized returns (address _removedAddress) {
    if (size == 0) revert LinkedList_EmptyList();
    if (_index >= size) revert LinkedList_InvalidIndex(_index);
    uint256 _key = head;
    for (uint256 i = 0; i <= _index; i++) {
      if (i == _index) {
        _removedAddress = _nodes[_key].contractAddress;
        _nodes[_key].contractAddress = _contractAddress;
        return (_removedAddress);
      }
      _key = _nodes[_key].next;
    }
  }

  function replace(address _replacedAddress, address _contractAddress) external isAuthorized returns (bool _success) {
    if (size == 0) revert LinkedList_EmptyList();
    uint256 _key = head;
    uint256 _previousKey = 0;
    while (_key != 0) {
      if (_nodes[_key].contractAddress == _replacedAddress) {
        _nodes[_key].contractAddress = _contractAddress;
        return true;
      }
      _previousKey = _key;
      _key = _nodes[_key].next;
    }
  }
}
