pragma solidity 0.6.7;

import {SAFEEngine} from '../SAFEEngine.sol';

contract SAFEHandler {
  constructor(address safeEngine) public {
    SAFEEngine(safeEngine).approveSAFEModification(msg.sender);
  }
}
