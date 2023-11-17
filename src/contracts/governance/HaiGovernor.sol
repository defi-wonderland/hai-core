// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHaiGovernor} from '@interfaces/governance/IHaiGovernor.sol';

import {Governor} from '@openzeppelin/contracts/governance/Governor.sol';
import {GovernorSettings} from '@openzeppelin/contracts/governance/extensions/GovernorSettings.sol';
import {GovernorCountingSimple} from '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import {GovernorVotes, IVotes, Time} from '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';
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
    IHaiGovernor.HaiGovernorParams memory _params
  )
    Governor(_governorName)
    GovernorSettings(_params.votingDelay, _params.votingPeriod, _params.proposalThreshold)
    GovernorVotes(_token)
    GovernorVotesQuorumFraction(1) // TODO: set quorum
    GovernorTimelockControl(_timelock)
  {}

  /**
   * Set the clock to block timestamp, as opposed to the default block number.
   */

  function clock() public view override(Governor, GovernorVotes) returns (uint48) {
    return Time.timestamp();
  }

  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual override(Governor, GovernorVotes) returns (string memory) {
    return 'mode=timestamp';
  }

  /**
   * The following functions are overrides required by Solidity
   */

  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
    return super._executor();
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
    return super._queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function proposalNeedsQueuing(uint256 _proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns (bool)
  {
    return super.proposalNeedsQueuing(_proposalId);
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.proposalThreshold();
  }

  function state(uint256 _proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
    return super.state(_proposalId);
  }
}