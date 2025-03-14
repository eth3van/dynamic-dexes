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

contract Multiswap2Test is BaseTest {
    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc_public"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        deal({ token: USDT, to: user, give: 1000e18 });
    }

    // =========================
    // multiswap2
    // =========================

    function test_multiswapRouterComponent_multiswap2_shouldRevertIfMultiswap2DataIsInvalid() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        _resetPrank(user);

        // pairs array is empty
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPairsArray.selector);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data))) });

        // amountIn array length and pairs length are not equal
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidMultiswap2Calldata.selector);
        m2Data.tokenIn = USDT;
        m2Data.pairs = Solarray.bytes32Arrays(Solarray.bytes32s(BUSD_USDT_UniV3_3000));
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data))) });

        // fullAmountCheck
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidMultiswap2Calldata.selector);
        m2Data.tokenIn = USDT;
        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(1.001e18);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data))) });

        // not approved
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        m2Data.tokenIn = USDT;
        m2Data.amountInPercentages = Solarray.uint256s(1e18);
        m2Data.pairs = Solarray.bytes32Arrays(Solarray.bytes32s(BUSD_USDT_UniV3_3000));

        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data))) });
    }

    function test_multiswapRouterComponent_multiswap2_shouldSwapThroughAllUniswapV2Pairs() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.tokenIn = USDT;
        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.25e18, 0.25e18, 0.5e18);
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(USDT_USDC_Biswap), Solarray.bytes32s(USDT_USDC_Bakery), Solarray.bytes32s(USDT_USDC_Cake)
        );
        m2Data.tokenOut = USDC;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(IERC20(USDC).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_multiswap2_shouldSwapThroughAllUniswapV3Pairs() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.tokenIn = USDT;
        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.25e18, 0.25e18, 0.5e18);
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_USDT_UniV3_3000),
            Solarray.bytes32s(WBNB_USDT_UniV3_500),
            Solarray.bytes32s(WBNB_USDT_CakeV3_500)
        );
        m2Data.tokenOut = WBNB;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(IERC20(WBNB).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_multiswap2_shouldRevertIfAmountOutLtMinAmountOut() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.tokenIn = USDT;
        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.25e18, 0.25e18, 0.5e18);
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_USDT_UniV3_3000),
            Solarray.bytes32s(WBNB_USDT_UniV3_500),
            Solarray.bytes32s(WBNB_USDT_CakeV3_500)
        );
        m2Data.tokenOut = WBNB;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut + 1;

        _resetPrank(user);
        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountOut.selector);
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }

    // =========================
    // partswap with native
    // =========================

    function test_multiswapRouterComponent_multiswap2_partswapNativeThroughV2V3Pairs() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        deal({ to: user, give: 10e18 });

        m2Data.fullAmount = 10e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.1e18, 0.2e18, 0.3e18, 0.3e18, 0.1e18);
        m2Data.tokenIn = address(0);
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_ETH_Cake),
            Solarray.bytes32s(WBNB_ETH_CakeV3_500),
            Solarray.bytes32s(WBNB_ETH_UniV3_500),
            Solarray.bytes32s(WBNB_ETH_UniV3_3000),
            Solarray.bytes32s(WBNB_ETH_Bakery)
        );
        m2Data.tokenOut = ETH;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);

        factory.multicall{ value: 10e18 }({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(IERC20(ETH).balanceOf({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_multiswap2_swapToNativeThroughV2V3Pairs() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.1e18, 0.2e18, 0.3e18, 0.4e18);
        m2Data.tokenIn = USDT;
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_USDT_UniV3_500),
            Solarray.bytes32s(WBNB_USDT_CakeV3_100),
            Solarray.bytes32s(WBNB_USDT_Biswap),
            Solarray.bytes32s(WBNB_USDT_Cake)
        );
        m2Data.tokenOut = WBNB;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        uint256 userBalanceBefore = user.balance;

        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user))
            )
        });

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);
    }

    // =========================
    // multiswap2 with fee
    // =========================

    function test_multiswapRouterComponent_multiswap2_shouldCalculateFee() external checkTokenStorage {
        _resetPrank(owner);
        quoter.setFeeContract({ newFeeContract: address(feeContract) });
        // 0.03%
        feeContract.setProtocolFee({ newProtocolFee: 300 });

        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.1e18, 0.2e18, 0.3e18, 0.4e18);
        m2Data.tokenIn = USDT;
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_USDT_UniV3_500),
            Solarray.bytes32s(WBNB_USDT_CakeV3_100),
            Solarray.bytes32s(WBNB_USDT_Biswap),
            Solarray.bytes32s(WBNB_USDT_Cake)
        );
        m2Data.tokenOut = WBNB;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut;

        _resetPrank(user);

        IERC20(USDT).approve({ spender: address(factory), amount: 100e18 });

        uint256 userBalanceBefore = user.balance;

        _expectERC20TransferCall(WBNB, address(feeContract), quoterAmountOut * 300 / (1e6 - 300));
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user))
            )
        });

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);
        assertEq(feeContract.profit({ owner: address(feeContract), token: WBNB }), quoterAmountOut * 300 / (1e6 - 300));
    }

    // =========================
    // no transfer revert
    // =========================

    function test_multiswapRouterComponent_multiswap2_noTransferRevert() external checkTokenStorage {
        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        deal({ token: USDT, to: address(factory), give: 100e18 });

        m2Data.tokenIn = USDT;
        m2Data.fullAmount = 100e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.25e18, 0.25e18, 0.5e18);
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(WBNB_USDT_UniV3_3000),
            Solarray.bytes32s(WBNB_USDT_UniV3_500),
            Solarray.bytes32s(WBNB_USDT_CakeV3_500)
        );

        _resetPrank(user);
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }
}
