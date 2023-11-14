// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Governor} from '@openzeppelin/contracts/governance/Governor.sol';
import {GovernorSettings} from '@openzeppelin/contracts/governance/extensions/GovernorSettings.sol';
import {GovernorCountingSimple} from '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import {GovernorVotes, IVotes} from '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';
import {GovernorVotesQuorumFraction} from
  '@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol';
import {
  GovernorTimelockControl,
  TimelockController
} from '@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol';

contract HaiGovernor is
  Governor,
  GovernorSettings,
  GovernorCountingSimple,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorTimelockControl
{
  constructor(
    IVotes _token,
    TimelockController _timelock,
    string memory _governorName,
    uint48 _votingDelay,
    uint32 _votingPeriod,
    uint256 _proposalThreshold
  )
    Governor(_governorName)
    GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
    GovernorVotes(_token)
    GovernorVotesQuorumFraction(1) // TODO: set quorum
    GovernorTimelockControl(_timelock)
  {}

  /**
   * The following functions are overrides required by Solidity
   * Overrides are chosen priority-wise from most to least specific
   */

  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(GovernorTimelockControl, Governor) returns (uint256) {
    return super._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(GovernorTimelockControl, Governor) {
    super._executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function _executor() internal view override(GovernorTimelockControl, Governor) returns (address) {
    return super._executor();
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(GovernorTimelockControl, Governor) returns (uint48) {
    return super._queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function proposalNeedsQueuing(uint256 _proposalId)
    public
    view
    override(GovernorTimelockControl, Governor)
    returns (bool)
  {
    return super.proposalNeedsQueuing(_proposalId);
  }

  function proposalThreshold() public view override(GovernorSettings, Governor) returns (uint256) {
    return super.proposalThreshold();
  }

  function state(uint256 _proposalId) public view override(GovernorTimelockControl, Governor) returns (ProposalState) {
    return super.state(_proposalId);
  }
}
