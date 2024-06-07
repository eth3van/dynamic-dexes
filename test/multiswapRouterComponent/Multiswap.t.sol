// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";
import { DeployFactory } from "../../script/DeployContract.s.sol";

import { Proxy, InitialImplementation } from "../../src/proxy/Proxy.sol";

import { IFactory } from "../../src/Factory.sol";
import { MultiswapRouterComponent, IMultiswapRouterComponent } from "../../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { IOwnable } from "../../src/external/IOwnable.sol";
import { TransferHelper } from "../../src/components/libraries/TransferHelper.sol";

import { Quoter } from "../../src/lens/Quoter.sol";

import "../Helpers.t.sol";

contract MultiswapTest is Test {
    IFactory router;
    Quoter quoter;

    // TODO add later
    // FeeContract feeContract;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address multiswapRouterComponent;
    address transferComponent;
    address factoryImplementation;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        deal(USDT, user, 1000e18);

        startHoax(owner);

        quoter = new Quoter(WBNB);

        multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        transferComponent = address(new TransferComponent(WBNB));

        factoryImplementation = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent, address(0));

        router = IFactory(address(new Proxy(owner)));

        // TODO add later
        // bytes[] memory initData =
        // Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.setFeeContract, address(feeContract)));

        InitialImplementation(address(router)).upgradeTo(
            factoryImplementation, abi.encodeCall(IFactory.initialize, (owner, new bytes[](0)))
        );

        vm.stopPrank();
    }

    // =========================
    // constructor
    // =========================

    function test_multiswapRouterComponent_constructor_shouldInitializeInConstructor() external {
        MultiswapRouterComponent _multiswapRouterComponent = new MultiswapRouterComponent(WBNB);
        TransferComponent _transferComponent = new TransferComponent(WBNB);
        _transferComponent;

        assertEq(_multiswapRouterComponent.wrappedNative(), WBNB);
    }

    // =========================
    // setFeeContract
    // =========================

    function test_multiswapRouterComponent_setFeeContract_shouldSetFeeContract() external {
        assertEq(IMultiswapRouterComponent(address(router)).feeContract(), address(0));

        hoax(user);
        vm.expectRevert(abi.encodeWithSelector(IOwnable.Ownable_SenderIsNotOwner.selector, user));
        IMultiswapRouterComponent(address(router)).setFeeContract(user);

        hoax(owner);
        IMultiswapRouterComponent(address(router)).setFeeContract(owner);

        assertEq(IMultiswapRouterComponent(address(router)).feeContract(), owner);
    }

    // =========================
    // transferNative
    // =========================

    function test_transferComponent_transferNative_shouldTransferNativeFromContract() external {
        deal(address(router), 10e18);

        startHoax(user);

        uint256 balanceBefore = user.balance;

        router.multicall(Solarray.bytess(abi.encodeCall(TransferComponent.transferNative, (user, 5e18))));

        uint256 balanceAfter = user.balance;

        assertEq(balanceAfter - balanceBefore, 5e18);

        router.multicall(Solarray.bytess(abi.encodeCall(TransferComponent.transferNative, (user, 5e18))));

        assertEq(user.balance - balanceAfter, 5e18);

        vm.stopPrank();
    }

    // =========================
    // multiswap
    // =========================

    function test_multiswapRouterComponent_multiswap_shouldRevertIfMultiswapDataIsInvalid() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        startHoax(user);

        // pairs array is empty
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPairsArray.selector);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        // amountIn is 0
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        // tokenIn is address(0) (native) and msg.value < amountIn
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.amountIn = 1;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        // not approved
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        IERC20(USDT).approve(address(router), 100e18);

        // tokenIn is not in sent pair
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000, WBNB_CAKE_CakeV3_500);
        router.multicall(Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))));

        vm.stopPrank();
    }

    function test_multiswapRouterComponent_multiswap_shouldSwapThroughAllUniswapV2Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
            Solarray.bytes32s(USDT_USDC_Cake, USDC_CAKE_Cake, BUSD_CAKE_Biswap, BUSD_ETH_Biswap, WBNB_ETH_Bakery);

        uint256 quoterAmountOut = quoter.multiswap(mData);

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        startHoax(user);
        IERC20(USDT).approve(address(router), 100e18);

        router.multicall(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        );

        assertEq(IERC20(WBNB).balanceOf(user), quoterAmountOut);

        vm.stopPrank();
    }

    function test_multiswapRouterComponent_multiswap_shouldSwapThroughAllUniswapV3Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(
            ETH_USDT_UniV3_500, WBNB_ETH_UniV3_500, WBNB_CAKE_UniV3_3000, WBNB_CAKE_CakeV3_500, WBNB_ETH_UniV3_3000
        );

        uint256 quoterAmountOut = quoter.multiswap(mData);

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        startHoax(user);
        IERC20(USDT).approve(address(router), 100e18);

        router.multicall(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (ETH, 0, user))
            )
        );

        assertEq(IERC20(ETH).balanceOf(user), quoterAmountOut);

        vm.stopPrank();
    }

    function test_multiswapRouterComponent_failedV3Swap() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        deal(USDC, user, 100e18);

        mData.amountIn = 100e18;
        mData.tokenIn = USDC;
        mData.pairs = Solarray.bytes32s(USDC_CAKE_UniV3_500);

        assertEq(quoter.multiswap(mData), 0);

        startHoax(user);
        IERC20(USDC).approve(address(router), 100e18);

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_FailedV3Swap.selector);
        router.multicall(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        );

        vm.stopPrank();
    }

    function test_multiswapRouterComponent_failedCallback() external {
        (, bytes memory data) = multiswapRouterComponent.call(abi.encodeWithSelector(TransferComponent.transferToken.selector));

        assertEq(bytes4(data), IMultiswapRouterComponent.MultiswapRouterComponent_SenderMustBeUniswapV3Pool.selector);
    }

    function test_multiswapRouterComponent_multiswap_shouldRevertIfAmountOutLtMinAmountOut() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
            Solarray.bytes32s(USDT_USDC_Cake, USDC_CAKE_Cake, BUSD_CAKE_Biswap, BUSD_ETH_Biswap, WBNB_ETH_Bakery);

        uint256 quoterAmountOut = quoter.multiswap(mData);

        mData.minAmountOut = quoterAmountOut + 1;

        startHoax(user);
        IERC20(USDT).approve(address(router), 100e18);

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountOut.selector);
        router.multicall(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        );

        vm.stopPrank();
    }

    // =========================
    // multiswap with native
    // =========================

    function test_multiswapRouterComponent_multiswapNative() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 10e18;
        mData.tokenIn = address(0);
        mData.pairs =
            Solarray.bytes32s(WBNB_ETH_Bakery, BUSD_ETH_Biswap, BUSD_CAKE_Biswap, USDC_CAKE_Cake, USDT_USDC_Cake);

        uint256 quoterAmountOut = quoter.multiswap(mData);

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        startHoax(user);

        uint256 userBalanceBefore = IERC20(USDT).balanceOf(user);

        router.multicall{ value: 10e18 }(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (USDT, 0, user))
            )
        );

        assertEq(IERC20(USDT).balanceOf(user) - userBalanceBefore, quoterAmountOut);

        vm.stopPrank();
    }

    function test_multiswapRouterComponent_swapToNativeThroughV2V3Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_Cake, BUSD_USDC_CakeV3_100, BUSD_CAKE_Cake, WBNB_CAKE_CakeV3_100);

        uint256 quoterAmountOut = quoter.multiswap(mData);

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        startHoax(user);

        IERC20(USDT).approve(address(router), 100e18);

        uint256 userBalanceBefore = user.balance;

        router.multicall(
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user, 0))
            )
        );

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);

        vm.stopPrank();
    }
}
