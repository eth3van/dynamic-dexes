// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest, IERC20, Solarray, IStargateComponent, LayerZeroComponent, ILayerZeroComponent } from "../BaseTest.t.sol";
import { Origin } from "../../src/components/bridges/stargate/ILayerZeroEndpointV2.sol";

import "../Helpers.t.sol";

contract LayerZeroComponentTest is BaseTest {
    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        ILayerZeroComponent(address(factory)).setDefaultGasLimit({ defaultGasLimit_: 50_000 });
        ILayerZeroComponent(address(factory)).setDelegate({ delegate: owner });
    }

    // =========================
    // getters and setters
    // =========================

    function test_layerZeroComponent_gettersAndSetters() external {
        _resetPrank(owner);

        new LayerZeroComponent({ endpointV2: contracts.endpointV2 });

        assertEq(ILayerZeroComponent(address(factory)).eid(), 30_102);

        assertEq(ILayerZeroComponent(address(factory)).defaultGasLimit(), 50_000);

        ILayerZeroComponent(address(factory)).setDefaultGasLimit({ defaultGasLimit_: 100_000 });
        assertEq(ILayerZeroComponent(address(factory)).defaultGasLimit(), 100_000);

        assertTrue(ILayerZeroComponent(address(factory)).isSupportedEid({ remoteEid: 30_101 }));
        assertEq(
            ILayerZeroComponent(address(factory)).getPeer({ remoteEid: 30_101 }),
            bytes32(uint256(uint160(address(factory))))
        );

        vm.expectRevert(ILayerZeroComponent.LayerZeroComponent_LengthMismatch.selector);
        ILayerZeroComponent(address(factory)).setPeers({
            remoteEids: Solarray.uint32s(30_101, 1),
            remoteAddresses: Solarray.bytes32s(bytes32(uint256(uint160(owner))))
        });

        ILayerZeroComponent(address(factory)).setPeers({
            remoteEids: Solarray.uint32s(30_101),
            remoteAddresses: Solarray.bytes32s(bytes32(uint256(uint160(owner))))
        });
        assertEq(ILayerZeroComponent(address(factory)).getPeer({ remoteEid: 30_101 }), bytes32(uint256(uint160(owner))));

        assertEq(ILayerZeroComponent(address(factory)).getDelegate(), owner);

        ILayerZeroComponent(address(factory)).setDelegate({ delegate: address(this) });
        assertEq(ILayerZeroComponent(address(factory)).getDelegate(), address(this));

        assertEq(ILayerZeroComponent(address(factory)).getGasLimit({ remoteEid: 30_101 }), 100_000);

        vm.expectRevert(ILayerZeroComponent.LayerZeroComponent_LengthMismatch.selector);
        ILayerZeroComponent(address(factory)).setGasLimit({
            remoteEids: Solarray.uint32s(30_101, 1),
            gasLimits: Solarray.uint128s(30_000)
        });

        ILayerZeroComponent(address(factory)).setGasLimit({
            remoteEids: Solarray.uint32s(30_101),
            gasLimits: Solarray.uint128s(30_000)
        });
        assertEq(ILayerZeroComponent(address(factory)).getGasLimit({ remoteEid: 30_101 }), 30_000);

        assertEq(ILayerZeroComponent(address(factory)).getNativeSendCap({ remoteEid: 30_101 }), 0.24e18);

        assertTrue(ILayerZeroComponent(address(factory)).isSupportedEid({ remoteEid: 30_101 }));

        assertFalse(
            ILayerZeroComponent(address(factory)).allowInitializePath({
                origin: Origin({ srcEid: 0, sender: bytes32(0), nonce: 1 })
            })
        );

        assertEq(ILayerZeroComponent(address(factory)).nextNonce(0, bytes32(0)), 0);
    }

    // =========================
    // sendDeposit
    // =========================

    uint32 remoteEidV2 = 30_101;
    address stargatePool = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63;

    function test_layerZeroComponent_sendDeposit_shoudRevertIfFeeNotMet() external {
        uint128 nativeTransferCap = ILayerZeroComponent(address(factory)).getNativeSendCap({ remoteEid: remoteEidV2 });

        uint256 fee = ILayerZeroComponent(address(factory)).estimateFee({
            remoteEid: remoteEidV2,
            nativeAmount: nativeTransferCap,
            to: address(0)
        });

        deal({ token: USDT, to: user, give: 1000e18 });
        deal({ to: user, give: 1000e18 });

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 1000e18 });

        (uint256 _fee,) = IStargateComponent(address(factory)).quoteV2({
            poolAddress: stargatePool,
            dstEid: remoteEidV2,
            amountLD: 1000e18,
            composer: user,
            composeMsg: bytes(""),
            composeGasLimit: 0
        });

        vm.expectRevert(ILayerZeroComponent.LayerZeroComponent_FeeNotMet.selector);
        factory.multicall{ value: (fee + _fee) >> 1 }({
            data: Solarray.bytess(
                abi.encodeCall(IStargateComponent.sendStargateV2, (stargatePool, remoteEidV2, 1000e18, user, 0, bytes(""))),
                abi.encodeCall(ILayerZeroComponent.sendDeposit, (remoteEidV2, nativeTransferCap, user))
            )
        });
    }

    function test_layerZeroComponent_sendDeposit_shoudSendDeposit() external {
        uint128 nativeTransferCap = ILayerZeroComponent(address(factory)).getNativeSendCap({ remoteEid: remoteEidV2 });

        uint256 fee = ILayerZeroComponent(address(factory)).estimateFee({
            remoteEid: remoteEidV2,
            nativeAmount: nativeTransferCap,
            to: address(0)
        });

        deal({ token: USDT, to: user, give: 1000e18 });
        deal({ to: user, give: 1000e18 });

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 1000e18 });

        (uint256 _fee,) = IStargateComponent(address(factory)).quoteV2({
            poolAddress: stargatePool,
            dstEid: remoteEidV2,
            amountLD: 1000e18,
            composer: user,
            composeMsg: bytes(""),
            composeGasLimit: 0
        });

        factory.multicall{ value: fee + _fee }({
            data: Solarray.bytess(
                abi.encodeCall(IStargateComponent.sendStargateV2, (stargatePool, remoteEidV2, 1000e18, user, 0, bytes(""))),
                abi.encodeCall(ILayerZeroComponent.sendDeposit, (remoteEidV2, nativeTransferCap, user))
            )
        });
    }
}
