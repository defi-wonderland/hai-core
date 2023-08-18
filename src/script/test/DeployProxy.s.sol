// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/test/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script DeployProxy --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProxy --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract DeployProxy is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    deploy();
    vm.stopBroadcast();
  }
}
