// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployMainnet} from '@script/Deploy.s.sol';

abstract contract E2EGovernorTest is HaiTest, Deploy {
  address whale = address(0x420);

  function test_proposal_lifecycle() public {
    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    string memory description;

    targets[0] = address(protocolToken);
    callDatas[0] = abi.encodeWithSignature('unpause()');
    values[0] = 0;
    description = 'Unpause the protocol';

    vm.startPrank(whale);
    uint256 _proposalId = haiGovernor.propose(targets, values, callDatas, description);

    vm.expectRevert();
    protocolToken.transfer(address(0x69), 1);

    vm.expectRevert(); // TODO: add revert message
    haiGovernor.castVote(_proposalId, 1);

    vm.warp(block.timestamp + _governorParams.votingDelay + 1);
    haiGovernor.castVote(_proposalId, 1);

    vm.expectRevert(); // TODO: add revert message
    haiGovernor.queue(targets, values, callDatas, keccak256(bytes(description)));

    vm.warp(block.timestamp + _governorParams.votingPeriod + 1);
    haiGovernor.queue(targets, values, callDatas, keccak256(bytes(description)));

    vm.expectRevert(); // TODO: add revert message
    haiGovernor.execute(targets, values, callDatas, keccak256(bytes(description)));

    vm.warp(block.timestamp + _governorParams.timelockMinDelay + 1);
    haiGovernor.execute(targets, values, callDatas, keccak256(bytes(description)));

    protocolToken.transfer(address(0x69), 1);
  }

  function test_proposal_cancel() public {
    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    string memory description;

    targets[0] = address(protocolToken);
    callDatas[0] = abi.encodeWithSignature('unpause()');
    values[0] = 0;
    description = 'Unpause the protocol';

    vm.prank(whale);
    haiGovernor.propose(targets, values, callDatas, description);

    vm.expectRevert();
    haiGovernor.cancel(targets, values, callDatas, keccak256(bytes(description)));

    vm.prank(whale);
    haiGovernor.cancel(targets, values, callDatas, keccak256(bytes(description)));
  }
}

contract E2EGovernorMainnetTest is DeployMainnet, E2EGovernorTest {
  uint256 FORK_BLOCK = 112_420_000;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    super.setUp();
    run();

    vm.prank(address(timelock));
    protocolToken.mint(whale, 1_000_000e18);
    vm.prank(whale);
    protocolToken.delegate(whale);
    vm.warp(block.timestamp + 1);
  }

  function setupEnvironment() public override(Deploy, DeployMainnet) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(Deploy, DeployMainnet) {
    super.setupPostEnvironment();
  }
}
