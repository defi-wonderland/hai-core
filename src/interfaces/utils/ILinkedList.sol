// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title ILinkedList
 * @dev This interface is used to implement a linked list data structure
 * @dev goig to be implemented as FIFO, all the new items will be added at the end of the list, and the list will be iterated from the head to the end
 */
interface ILinkedList is IAuthorizable {
  error LinkedList_EmptyList();
  error LinkedList_InvalidIndex(uint256 _index);

  struct Node {
    address contractAddress; // Using address as the the value to store, but it could be bytes if we want to make it generic and store any type of data like we do with params
    uint256 next; // The pointer to the next element in the list, 0 means that there is no next element, so it's the end of the list, dont confuse this with indexes, these are keys
  }

  /**
   * @dev Returns the first element of the list
   * @return _head The head of the list
   */
  function head() external view returns (uint256 _head);

  /**
   * @dev Returns the key of last element of the list
   * @return _tail The tail of the list
   */
  function tail() external view returns (uint256 _tail);

  /**
   * @dev Returns the size of the list
   * @return _size The size of the list
   */
  function size() external view returns (uint256 _size);

  /**
   * @dev Returns a node of the list given a key (this is not the index!)
   * @param _key The key of the node to return
   * @return _node The node of the list
   */
  function nodes(uint256 _key) external view returns (Node memory _node);

  /**
   * @dev Adds a new element to the end of the list
   * @param _contractAddress The address of the contract to add
   * @return _index The position in the list of the new element (it will be always the last one)
   */
  function push(address _contractAddress) external returns (uint256 _index);

  /**
   * @dev Removes the first element from a list
   * @return _contractAddress The address of the contract removed
   */
  function pop() external returns (address _contractAddress);

  /**
   * @dev Adds a new element to the list in the given index
   */
  function push(address _contractAddress, uint256 _index) external returns (bool _success);

  /**
   * @dev Removes an element from the list given the contract address
   * @param _contractAddress The address of the contract to remove
   * @return _success If the element was removed or not
   */
  function remove(address _contractAddress) external returns (bool _success);

  /**
   * @dev Removes an element from the list given the index (this is not the key! it's the position in the list)
   * @param _index The index of the element to remove
   * @return _success If the element was removed or not
   * @return _contractAddress The address of the contract removed
   */
  function remove(uint256 _index) external returns (bool _success, address _contractAddress);

  /**
   * @dev Replaces an element from the list given the contract address, and an index position (this is not the key! it's the position in the list)
   * @param _index The index of the element to replace
   * @param _contractAddress The address of the contract to replace
   * @return _removedAddress The address of the contract removed
   */
  function replace(uint256 _index, address _contractAddress) external returns (address _removedAddress);

  /**
   * @dev Replaces an element from the list given the contract address, and the address of the element to replace
   * @param _replacedAddress The address of the contract to replace
   * @param _contractAddress The address of the contract to replace
   * @return _success If the element was replaced or not
   */
  function replace(address _replacedAddress, address _contractAddress) external returns (bool _success);

  /**
   * @dev Returns the list of contracts
   * @return _list The list of contracts
   */
  function getList() external view returns (address[] memory _list);
}
