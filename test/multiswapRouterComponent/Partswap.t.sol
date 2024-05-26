// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";
import { DeployEngine } from "../../script/DeployEngine.sol";
import { DeployFactory } from "../../script/DeployContract.s.sol";

import { Proxy, InitialImplementation } from "../../src/proxy/Proxy.sol";

import { IFactory } from "../../src/Factory.sol";
import { MultiswapRouterComponent, IMultiswapRouterComponent } from "../../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { IOwnable } from "../../src/external/IOwnable.sol";

import { Quoter } from "../../src/lens/Quoter.sol";

import "../Helpers.t.sol";

contract PartswapTest is Test {
    MultiswapRouterComponent router;
    Quoter quoter;

    // TODO add later
    // FeeContract feeContract;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address multiswapRouterComponent;
    address transferComponent;
    address factoryImplementation;

    function setUp() external {
        vm.createSelectFork(vm.envString("BNB_RPC_URL"));

        startHoax(owner);

        quoter = new Quoter(WBNB);

        multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        transferComponent = address(new TransferComponent(WBNB));

        factoryImplementation = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent);

        router = MultiswapRouterComponent(address(new Proxy(owner)));

        // TODO add later
        // bytes[] memory initData =
        // Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.setFeeContract, address(feeContract)));

        InitialImplementation(address(router)).upgradeTo(
            factoryImplementation, abi.encodeCall(IFactory.initialize, (owner, new bytes[](0)))
        );

        vm.stopPrank();
    }
}
