// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";
import { DeployFactory } from "../../script/DeployContract.s.sol";

import { Proxy, InitialImplementation } from "../../src/proxy/Proxy.sol";

import { TransferHelper } from "../../src/components/libraries/TransferHelper.sol";

import { IFactory } from "../../src/Factory.sol";
import { MultiswapRouterComponent, IMultiswapRouterComponent } from "../../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { StargateComponent, IStargateComponent, IStargateComposer } from "../../src/components/bridges/StargateComponent.sol";
import { IOwnable } from "../../src/external/IOwnable.sol";
import { TransferHelper } from "../../src/components/libraries/TransferHelper.sol";

import { Quoter } from "../../src/lens/Quoter.sol";

import "../Helpers.t.sol";

contract StargateComponentTest is Test {
    IFactory bridge;
    Quoter quoter;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address multiswapRouterComponent;
    address transferComponent;
    address stargateComponent;
    address factoryImplementation;

    // bnb mainnet
    address endpointV2 = 0x1a44076050125825900e736c501f859c50fE728c;
    address stargateComposerV1 = 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        deal(USDT, user, 1000e18);

        startHoax(owner);

        quoter = new Quoter(WBNB);

        multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        transferComponent = address(new TransferComponent(WBNB));
        stargateComponent = address(new StargateComponent(endpointV2, stargateComposerV1));

        factoryImplementation = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent, stargateComponent);

        bridge = IFactory(address(new Proxy(owner)));

        InitialImplementation(address(bridge)).upgradeTo(
            factoryImplementation, abi.encodeCall(IFactory.initialize, (owner, new bytes[](0)))
        );

        vm.stopPrank();
    }

    // =========================
    // constructor
    // =========================

    function test_stargateComponent_constructor_shouldInitializeInConstructor() external {
        StargateComponent _stargateComponent = new StargateComponent(endpointV2, stargateComposerV1);

        assertEq(_stargateComponent.lzEndpoint(), endpointV2);
        assertEq(_stargateComponent.stargateV1Composer(), stargateComposerV1);
    }

    // =========================
    // unwrapNative
    // =========================

    function test_transferComponent_unwrapNative_shouldUnwrapNativeToken() external {
        deal(WBNB, address(bridge), 10e18);

        startHoax(user);

        assertEq(IERC20(WBNB).balanceOf(address(bridge)), 10e18);
        assertEq(address(bridge).balance, 0);

        bridge.multicall(Solarray.bytess(abi.encodeCall(TransferComponent.unwrapNative, (5e18))));

        assertEq(IERC20(WBNB).balanceOf(address(bridge)), 5e18);
        assertEq(address(bridge).balance, 5e18);

        bridge.multicall(Solarray.bytess(abi.encodeCall(TransferComponent.unwrapNative, (5e18))));

        assertEq(IERC20(WBNB).balanceOf(address(bridge)), 0);
        assertEq(address(bridge).balance, 10e18);

        vm.stopPrank();
    }

    // =========================
    // sendStargateV1
    // =========================

    uint16 dstChainIdV1 = 101;
    uint256 srcPoolIdV1 = 2;
    uint256 dstPoolIdV1_1 = 1;
    uint256 dstPoolIdV1_2 = 2;

    function test_stargateComponent_sendStargateV1_shouldSendStargateV1() external {
        deal(USDT, user, 1000e18);

        startHoax(user);

        IERC20(USDT).approve(address(bridge), 1000e18);

        IStargateComposer.lzTxObj memory lzTxObj =
            IStargateComposer.lzTxObj({ dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: bytes("") });

        uint256 fee = StargateComponent(address(bridge)).quoteV1(dstChainIdV1, user, bytes(""), lzTxObj);

        bridge.multicall{ value: fee }(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_1,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        fee = StargateComponent(address(bridge)).quoteV1(dstChainIdV1, user, bytes(""), lzTxObj);

        bridge.multicall{ value: fee }(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_2,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        vm.stopPrank();
    }

    function test_stargateComponent_sendStargateV1_shouldRevertIfFeeNotEnough() external {
        deal(USDT, user, 1000e18);

        startHoax(user);

        IERC20(USDT).approve(address(bridge), 1000e18);

        IStargateComposer.lzTxObj memory lzTxObj =
            IStargateComposer.lzTxObj({ dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: bytes("") });

        uint256 fee = StargateComponent(address(bridge)).quoteV1(dstChainIdV1, user, bytes(""), lzTxObj);

        vm.expectRevert(IStargateComponent.StargateComponent_InvalidNativeBalance.selector);
        bridge.multicall{ value: fee >> 1 }(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_1,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        fee = StargateComponent(address(bridge)).quoteV1(dstChainIdV1, user, bytes(""), lzTxObj);

        vm.expectRevert(IStargateComponent.StargateComponent_InvalidNativeBalance.selector);
        bridge.multicall{ value: fee >> 1 }(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_2,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        vm.stopPrank();
    }

    function test_stargateComponent_sendStargateV1_shouldRevertIftransferFromFailed() external {
        startHoax(user);

        IStargateComposer.lzTxObj memory lzTxObj =
            IStargateComposer.lzTxObj({ dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: bytes("") });

        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        bridge.multicall(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_1,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        deal(USDT, user, 1000e18);

        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        bridge.multicall(
            Solarray.bytess(
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_2,
                        500e18,
                        500e18 * 0.98e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                )
            )
        );

        vm.stopPrank();
    }

    // =========================
    // sendStargateV2
    // =========================

    uint32 dstEidV2 = 30_101;
    address stargatePool = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63;

    function test_stargateComponent_sendStargateV2_shouldSendStargateV2() external {
        deal(USDT, user, 1000e18);

        startHoax(user);

        IERC20(USDT).approve(address(bridge), 1000e18);

        (uint256 fee, uint256 amountOut) =
            StargateComponent(address(bridge)).quoteV2(stargatePool, dstEidV2, 1000e18, user, bytes(""), 0);

        assertApproxEqAbs(amountOut, 1000e18, 1000e18 * 0.997e18 / 1e18);

        bridge.multicall{ value: fee }(
            Solarray.bytess(
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 1000e18, user, 0, bytes("")))
            )
        );

        vm.stopPrank();
    }

    function test_stargateComponent_sendStargateV2_shouldRevertIfNativeBalanceNotEnough() external {
        deal(USDT, user, 1000e18);

        startHoax(user);

        IERC20(USDT).approve(address(bridge), 1000e18);

        (uint256 fee,) = StargateComponent(address(bridge)).quoteV2(stargatePool, dstEidV2, 1000e18, user, bytes(""), 0);

        vm.expectRevert(IStargateComponent.StargateComponent_InvalidNativeBalance.selector);
        bridge.multicall{ value: fee >> 1 }(
            Solarray.bytess(
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 1000e18, user, 0, bytes("")))
            )
        );

        vm.stopPrank();
    }

    function test_stargateComponent_sendStargateV2_shouldRevertIfTransferFromError() external {
        startHoax(user);

        (uint256 fee,) = StargateComponent(address(bridge)).quoteV2(stargatePool, dstEidV2, 1000e18, user, bytes(""), 0);

        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        bridge.multicall{ value: fee }(
            Solarray.bytess(
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 1000e18, user, 0, bytes("")))
            )
        );

        deal(USDT, user, 1000e18);

        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        bridge.multicall{ value: fee }(
            Solarray.bytess(
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 1000e18, user, 0, bytes("")))
            )
        );

        vm.stopPrank();
    }

    // =========================
    // sendStargate with multiswap
    // =========================

    function test_stargateComponent_sendStargateWithMultiswap_shouldSendStargateV1WithMultiswap() external {
        deal(WBNB, user, 1000e18);

        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 10e18;
        mData.tokenIn = WBNB;
        mData.pairs =
            Solarray.bytes32s(WBNB_ETH_Bakery, BUSD_ETH_Biswap, BUSD_CAKE_Biswap, USDC_CAKE_Cake, USDT_USDC_Cake);

        startHoax(user);

        IERC20(WBNB).approve(address(bridge), 1000e18);

        IStargateComposer.lzTxObj memory lzTxObj =
            IStargateComposer.lzTxObj({ dstGasForCall: 0, dstNativeAmount: 0, dstNativeAddr: bytes("") });

        uint256 fee = StargateComponent(address(bridge)).quoteV1(dstChainIdV1, user, bytes(""), lzTxObj);

        uint256 quoteMultiswap = quoter.multiswap(mData);

        bridge.multicall{ value: fee }(
            0x0000000000000000000000000000000000000000000000000000000000240064,
            Solarray.bytess(
                abi.encodeCall(MultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(
                    StargateComponent.sendStargateV1,
                    (
                        dstChainIdV1,
                        srcPoolIdV1,
                        dstPoolIdV1_1,
                        0,
                        quoteMultiswap * 0.97e18 / 1e18,
                        user,
                        bytes(""),
                        lzTxObj
                    )
                ),
                abi.encodeCall(TransferComponent.transferToken, (USDT, 0, user))
            )
        );

        assertEq(IERC20(USDT).balanceOf(address(bridge)), 0);
    }

    function test_stargateComponent_sendStargateWithMultiswap_shouldSendStargateV2WithMultiswap() external {
        deal(WBNB, user, 1000e18);

        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 10e18;
        mData.tokenIn = WBNB;
        mData.pairs =
            Solarray.bytes32s(WBNB_ETH_Bakery, BUSD_ETH_Biswap, BUSD_CAKE_Biswap, USDC_CAKE_Cake, USDT_USDC_Cake);

        startHoax(user);

        IERC20(WBNB).approve(address(bridge), 1000e18);

        uint256 quoteMultiswap = quoter.multiswap(mData);

        (uint256 fee,) =
            StargateComponent(address(bridge)).quoteV2(stargatePool, dstEidV2, quoteMultiswap, user, bytes(""), 0);

        bridge.multicall{ value: fee }(
            0x0000000000000000000000000000000000000000000000000000000000240044,
            Solarray.bytess(
                abi.encodeCall(MultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(StargateComponent.sendStargateV2, (stargatePool, dstEidV2, 0, user, 0, bytes(""))),
                abi.encodeCall(TransferComponent.transferToken, (USDT, 0, user))
            )
        );

        assertEq(IERC20(USDT).balanceOf(address(bridge)), 0);
    }
}
