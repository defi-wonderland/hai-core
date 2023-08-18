  // SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Deployment} from '@script/test/utils/Deployment.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// TODO update these scritps to work with the NFT-mods / new contracts

contract TestScripts is Deployment {
  /**
   * @dev this function calls the proxyFactory directly,
   * therefore it bypasses the proxyRegistry and proxy address
   * will not be saved in the proxyRegistry mapping
   */
  function deploy() public returns (address payable) {
    return proxyFactory.build();
  }

  /**
   * @dev this function calls the proxyFactory via ProxyRegistry,
   * and it will only allow 1 proxy per wallet/EOA.
   * use the `deployProxy` script to bypass the ProxyRegistry
   */
  function deployOrFind(address owner) public returns (address payable) {
    HaiProxy proxy = proxyRegistry.proxies(owner);
    if (proxy == HaiProxy(payable(address(0))) || proxy.owner() != owner) {
      return proxyRegistry.build(owner);
    } else {
      return payable(address(proxy));
    }
  }

  /**
   * @dev open new safe
   */
  function openSafe(bytes32 _cType, address _proxy) public returns (uint256 _safeId) {
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory safeData = HaiProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(safeData, (uint256));
  }

  /**
   * @dev lock collateral and generate debt
   * deltaWad can be set to zero to only lock collateral and generate zero debt
   */
  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev this function has a bug
   * in order to lockCollateral, use the lockCollatAndGenDebt script, with deltaWad (debt to generate) set to zero
   */
  function depositCollat(bytes32 _cType, uint256 _safeId, uint256 _collatAmount, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _collatAmount
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev generate debt from safe that has sufficient collateral locked
   */
  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(coinJoin),
      _safeId,
      _deltaWad
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }
}
