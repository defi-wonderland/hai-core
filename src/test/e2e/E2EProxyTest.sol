pragma solidity 0.6.7;

import {DSTest} from 'ds-test/test.sol';
import {
  Deploy,
  GebProxyActions,
  GebProxyRegistry,
  DSProxyFactory,
  GebSafeManager,
  GetSafes
} from '../../../script/Deploy.s.sol';

import {DSProxy} from '../../../src/contracts/proxies/DSProxy.sol';
import {BasicActions} from '../../../src/contracts/proxies/GebProxyActions.sol';

abstract contract ProxyLike {
  function execute(address, bytes memory) public payable virtual;
}

/**
 * TODO: 
 * - internalize all methods via virtual functions to swap between proxy and direct actions
 */
contract E2EProxyTest is DSTest {
  bytes32 constant COLLATERAL_TYPE = bytes32('ETH-A');

  Deploy public deployment;

  DSProxy public proxy;
  GebProxyActions public proxyActions;
  GebProxyRegistry public proxyRegistry;
  DSProxyFactory public dsProxyFactory;
  GebSafeManager public safeManager;
  GetSafes public getSafes;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();

    proxyActions = deployment.proxyActions();
    proxyRegistry = deployment.proxyRegistry();
    dsProxyFactory = deployment.dsProxyFactory();
    safeManager = deployment.safeManager();
    getSafes = deployment.getSafes();

    proxy = DSProxy(proxyRegistry.build());
  }

  function testOpenSafe() public {
    bytes memory _callData = abi.encodeWithSelector(
      BasicActions.openLockETHAndGenerateDebt.selector,
      address(safeManager),
      address(deployment.taxCollector()),
      address(deployment.collateralJoinWrapped()),
      address(deployment.coinJoin()),
      COLLATERAL_TYPE,
      1
    );

    // NOTE: using ProxyLike else "Error: Member "execute" not unique after argument-dependent lookup in contract DSProxy."
    // proxy.execute{value: 1e18}(address(proxyActions), _callData);
    ProxyLike(address(proxy)).execute{value: 1e18}(address(proxyActions), _callData);
  }
}
