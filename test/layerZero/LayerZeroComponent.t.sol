// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";
import { DeployEngine, Contracts, getContracts } from "../../script/DeployEngine.sol";

import { Proxy, InitialImplementation } from "../../src/proxy/Proxy.sol";

import { IFactory } from "../../src/Factory.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { StargateComponent, IStargateComponent, IStargateComposer } from "../../src/components/bridges/StargateComponent.sol";
import { LayerZeroComponent, UlnConfig } from "../../src/components/bridges/LayerZeroComponent.sol";
import { TransferHelper } from "../../src/components/libraries/TransferHelper.sol";

import "../Helpers.t.sol";

contract LayerZeroComponentTest is Test {
    IFactory bridge;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address factoryImplementation;
    Contracts contracts;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        contracts = getContracts(56);
        (contracts,) = DeployEngine.deployImplemetations(contracts, true);

        deal(USDT, user, 1000e18);

        startHoax(owner);

        factoryImplementation = DeployEngine.deployFactory(contracts);

        bridge = IFactory(address(new Proxy(owner)));

        InitialImplementation(address(bridge)).upgradeTo(
            factoryImplementation, abi.encodeCall(IFactory.initialize, (owner, new bytes[](0)))
        );

        LayerZeroComponent(address(bridge)).setDefaultGasLimit(50_000);
        LayerZeroComponent(address(bridge)).setDelegate(owner);

        vm.stopPrank();
    }

    // =========================
    // getters and setters
    // =========================

    function test_layerZeroComponent_gettersAndSetters() external {
        new LayerZeroComponent(contracts.endpointV2);

        assertEq(LayerZeroComponent(address(bridge)).eid(), 30_102);

        assertEq(LayerZeroComponent(address(bridge)).defaultGasLimit(), 50_000);

        hoax(owner);
        LayerZeroComponent(address(bridge)).setDefaultGasLimit(100_000);
        assertEq(LayerZeroComponent(address(bridge)).defaultGasLimit(), 100_000);

        assertTrue(LayerZeroComponent(address(bridge)).isSupportedEid(30_101));
        assertEq(LayerZeroComponent(address(bridge)).getPeer(30_101), bytes32(uint256(uint160(address(bridge)))));

        hoax(owner);
        LayerZeroComponent(address(bridge)).setPeers(
            Solarray.uint32s(30_101), Solarray.bytes32s(bytes32(uint256(uint160(owner))))
        );
        assertEq(LayerZeroComponent(address(bridge)).getPeer(30_101), bytes32(uint256(uint160(owner))));

        assertEq(LayerZeroComponent(address(bridge)).getDelegate(), owner);

        hoax(owner);
        LayerZeroComponent(address(bridge)).setDelegate(address(this));
        assertEq(LayerZeroComponent(address(bridge)).getDelegate(), address(this));

        assertEq(LayerZeroComponent(address(bridge)).getGasLimit(30_101), 100_000);

        hoax(owner);
        LayerZeroComponent(address(bridge)).setGasLimit(Solarray.uint32s(30_101), Solarray.uint128s(30_000));
        assertEq(LayerZeroComponent(address(bridge)).getGasLimit(30_101), 30_000);

        assertEq(LayerZeroComponent(address(bridge)).getNativeSendCap(30_101), 0.24e18);

        assertTrue(LayerZeroComponent(address(bridge)).isSupportedEid(30_101));
    }

    // =========================
    // sendDeposit
    // =========================

    uint32 dstEidV2 = 30_101;
    address stargatePool = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63;

    function test_layerZeroComponent_sendDeposit_shoudSendDeposit() external {
        uint128 nativeTransferCap = LayerZeroComponent(address(bridge)).getNativeSendCap(dstEidV2);

        uint256 fee = LayerZeroComponent(address(bridge)).estimateFee(dstEidV2, nativeTransferCap, address(0));

        deal(USDT, user, 1000e18);

        startHoax(user);

        IERC20(USDT).approve(address(bridge), 1000e18);

        (uint256 _fee,) = StargateComponent(address(bridge)).quoteV2(stargatePool, dstEidV2, 1000e18, user, bytes(""), 0);

        bridge.multicall{ value: fee + _fee }(
            Solarray.bytess(
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 1000e18, user, 0, bytes(""))),
                abi.encodeCall(LayerZeroComponent.sendDeposit, (dstEidV2, nativeTransferCap, address(0)))
            )
        );

        vm.stopPrank();
    }
}
