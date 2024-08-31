// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    BaseTest,
    IERC20,
    Solarray,
    IOwnable,
    TransferHelper,
    MultiswapRouterComponent,
    IMultiswapRouterComponent,
    TransferComponent,
    ITransferComponent
} from "../BaseTest.t.sol";

import "../Helpers.t.sol";

contract PartswapTest is BaseTest {
    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        deal({ token: USDT, to: user, give: 1000e18 });
    }

    // =========================
    // partswap
    // =========================

    function test_multiswapRouterComponent_partswap_shouldRevertIfPartswapDataIsInvalid() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        _resetPrank(user);

        // pairs array is empty
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPairsArray.selector);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.partswap, (pData))) });

        // amountIn array length and pairs length are not equal
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPartswapCalldata.selector);
        pData.tokenIn = USDT;
        pData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.partswap, (pData))) });

        // fullAmountCheck
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPartswapCalldata.selector);
        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(100.1e18);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.partswap, (pData))) });

        // not approved
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        pData.tokenIn = USDT;
        pData.amountsIn = Solarray.uint256s(100e18);
        pData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.partswap, (pData))) });
    }

    function test_multiswapRouterComponent_partswap_shouldSwapThroughAllUniswapV2Pairs() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(25e18, 25e18, 50e18);
        pData.pairs = Solarray.bytes32s(USDT_USDC_Biswap, USDT_USDC_Bakery, USDT_USDC_Cake);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = USDC;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (USDC, 0, user))
            )
        });

        assertEq(IERC20(USDC).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_partswap_shouldSwapThroughAllUniswapV2PairsWithRemain() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(25e18, 25e18, 25e18);
        pData.pairs = Solarray.bytes32s(USDT_USDC_Biswap, USDT_USDC_Bakery, USDT_USDC_Cake);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = USDC;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (USDC, 0, user))
            )
        });

        assertEq(IERC20(USDC).balanceOf({ account: user }), quoterAmountOut);
        assertEq(IERC20(USDT).balanceOf({ account: user }), 925e18);
    }

    function test_multiswapRouterComponent_partswap_shouldSwapThroughAllUniswapV3Pairs() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(25e18, 25e18, 50e18);
        pData.pairs = Solarray.bytes32s(WBNB_USDT_CakeV3_500, WBNB_USDT_UniV3_500, WBNB_USDT_UniV3_3000);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = WBNB;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        });

        assertEq(IERC20(WBNB).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_partswap_shouldSwapThroughAllUniswapV3PairsWithRemain() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(25e18, 25e18, 25e18);
        pData.pairs = Solarray.bytes32s(WBNB_USDT_CakeV3_500, WBNB_USDT_UniV3_500, WBNB_USDT_UniV3_3000);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = WBNB;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        });

        assertEq(IERC20(WBNB).balanceOf({ account: user }), quoterAmountOut);
        assertEq(IERC20(USDT).balanceOf({ account: user }), 925e18);
    }

    function test_multiswapRouterComponent_partswap_shouldRevertIfAmountOutLtMinAmountOut() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.tokenIn = USDT;
        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(25e18, 25e18, 25e18);
        pData.pairs = Solarray.bytes32s(WBNB_USDT_CakeV3_500, WBNB_USDT_UniV3_500, WBNB_USDT_UniV3_3000);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut + 1;
        pData.tokenOut = WBNB;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountOut.selector);
        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (WBNB, 0, user))
            )
        });
    }

    // =========================
    // partswap with native
    // =========================

    function test_multiswapRouterComponent_partswap_partswapNativeThroughV2V3Pairs() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        deal({ to: user, give: 10e18 });

        pData.fullAmount = 10e18;
        pData.amountsIn = Solarray.uint256s(1e18, 2e18, 3e18, 3e18, 1e18);
        pData.tokenIn = address(0);
        pData.pairs = Solarray.bytes32s(
            WBNB_ETH_Bakery, WBNB_ETH_UniV3_3000, WBNB_ETH_UniV3_500, WBNB_ETH_CakeV3_500, WBNB_ETH_Cake
        );

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = ETH;

        _resetPrank(user);

        factory.multicall{ value: 10e18 }({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (ETH, 0, user))
            )
        });

        assertEq(IERC20(ETH).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_partswap_partswapNativeThroughV2V3PairsWithRemain() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        deal({ to: user, give: 10e18 });

        pData.fullAmount = 10e18;
        pData.amountsIn = Solarray.uint256s(1e18, 2e18, 3e18, 2e18, 1e18);
        pData.tokenIn = address(0);
        pData.pairs = Solarray.bytes32s(
            WBNB_ETH_Bakery, WBNB_ETH_UniV3_3000, WBNB_ETH_UniV3_500, WBNB_ETH_CakeV3_500, WBNB_ETH_Cake
        );

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = ETH;

        _resetPrank(user);

        factory.multicall{ value: 10e18 }({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.transferToken, (ETH, 0, user))
            )
        });

        assertEq(IERC20(ETH).balanceOf({ account: user }), quoterAmountOut);
        assertEq(IERC20(WBNB).balanceOf({ account: user }), 1e18);
    }

    function test_multiswapRouterComponent_partswap_swapToNativeThroughV2V3Pairs() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(10e18, 20e18, 30e18, 40e18);
        pData.tokenIn = USDT;
        pData.pairs = Solarray.bytes32s(WBNB_USDT_Cake, WBNB_USDT_Biswap, WBNB_USDT_CakeV3_100, WBNB_USDT_UniV3_500);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = WBNB;

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        uint256 userBalanceBefore = user.balance;

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user, 0))
            )
        });

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);
    }

    function test_multiswapRouterComponent_partswap_swapToNativeThroughV2V3PairsWithRemain() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(10e18, 20e18, 30e18, 30e18);
        pData.tokenIn = USDT;
        pData.pairs = Solarray.bytes32s(WBNB_USDT_Cake, WBNB_USDT_Biswap, WBNB_USDT_CakeV3_100, WBNB_USDT_UniV3_500);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;
        pData.tokenOut = WBNB;

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        uint256 userBalanceBefore = user.balance;

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user, 0))
            )
        });

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);
        assertEq(IERC20(USDT).balanceOf({ account: user }), 910e18);
    }

    // =========================
    // partswap with fee
    // =========================

    function test_multiswapRouterComponent_partswap_shouldCalculateFee() external {
        IMultiswapRouterComponent.PartswapCalldata memory pData;

        pData.fullAmount = 100e18;
        pData.amountsIn = Solarray.uint256s(10e18, 20e18, 30e18, 40e18);
        pData.tokenIn = USDT;
        pData.pairs = Solarray.bytes32s(WBNB_USDT_Cake, WBNB_USDT_Biswap, WBNB_USDT_CakeV3_100, WBNB_USDT_UniV3_500);

        uint256 quoterAmountOut = quoter.partswap({ data: pData });

        pData.minAmountOut = quoterAmountOut;
        pData.tokenOut = WBNB;

        _resetPrank(owner);
        // 0.03%
        feeContract.setProtocolFee({ newProtocolFee: 300 });

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        uint256 userBalanceBefore = user.balance;

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.partswap, (pData)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user, 0))
            )
        });

        uint256 fee = quoterAmountOut * 300 / 1e6;

        assertApproxEqAbs(user.balance - userBalanceBefore, quoterAmountOut - fee, 0.0001e18);
        assertEq(feeContract.profit({ owner: address(feeContract), token: WBNB }), fee);
    }
}
