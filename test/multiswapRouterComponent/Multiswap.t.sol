// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    IERC20,
    BaseTest,
    Solarray,
    IOwnable,
    TransferHelper,
    MultiswapRouterComponent,
    IMultiswapRouterComponent,
    TransferComponent,
    ITransferComponent,
    ISignatureTransfer,
    console2,
    TransientStorageComponentLibrary
} from "../BaseTest.t.sol";

import "../Helpers.t.sol";

contract MultiswapTest is BaseTest {
    using TransferHelper for address;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc_public"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        deal({ token: USDT, to: user, give: 1000e18 });

        _resetPrank(user);

        USDT.safeApprove({ spender: contracts.permit2, value: 1000e18 });
    }

    // =========================
    // constructor
    // =========================

    function test_multiswapRouterComponent_constructor_shouldInitializeInConstructor() external {
        MultiswapRouterComponent _multiswapRouterComponent =
            new MultiswapRouterComponent({ wrappedNative_: contracts.wrappedNative });
        TransferComponent _transferComponent =
            new TransferComponent({ wrappedNative: contracts.wrappedNative, permit2: contracts.permit2 });
        _transferComponent;

        assertEq(_multiswapRouterComponent.wrappedNative(), contracts.wrappedNative);
    }

    // =========================
    // transferFromPermit2
    // =========================

    function test_transferComponent_transferFromPermit2_shouldFailIfTokenNotApproved() external {
        _resetPrank(user);

        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });

        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 0 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        vm.expectRevert();
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 10_000e18, nonce, block.timestamp, signature))
            )
        });
    }

    function test_transferComponent_transferFromPermit2_shouldRevertIfTokenAmountIsZeroOrTransferFromFailed() external {
        _resetPrank(user);

        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });

        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 0 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        vm.expectRevert(ITransferComponent.TransferComponent_TransferFromFailed.selector);
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 0, nonce, block.timestamp, signature))
            )
        });
    }

    function test_transferComponent_transferFromPermit2_shouldTransferFrom257Times() external {
        _resetPrank(user);

        for (uint256 i; i < 257; ++i) {
            uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });

            bytes memory signature = _permit2Sign(
                userPk,
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 1e18 }),
                    nonce: nonce,
                    deadline: block.timestamp
                })
            );

            factory.multicall({
                data: Solarray.bytess(
                    abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 1e18, nonce, block.timestamp, signature))
                )
            });
        }
    }

    // =========================
    // multiswap
    // =========================

    function test_multiswapRouterComponent_multiswap_shouldRevertIfMultiswapDataIsInvalid() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        _resetPrank(user);

        // pairs array is empty
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPairsArray.selector);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });

        // amountIn is 0
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });

        // tokenIn is address(0) (native) and msg.value < amountIn
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.amountIn = 1;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });

        // not approved
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });

        USDT.safeApprove({ spender: address(factory), value: 100e18 });

        // tokenIn is not in sent pair
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000, WBNB_CAKE_CakeV3_500);
        factory.multicall({ data: Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData))) });
    }

    function test_multiswapRouterComponent_multiswap_shouldSwapThroughAllUniswapV2Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
            Solarray.bytes32s(USDT_USDC_Cake, USDC_CAKE_Cake, BUSD_CAKE_Biswap, BUSD_ETH_Biswap, WBNB_ETH_Bakery);

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        _resetPrank(user);
        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(WBNB.safeGetBalance({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_multiswap_shouldSwapThroughAllUniswapV3Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(
            ETH_USDT_UniV3_500, WBNB_ETH_UniV3_500, WBNB_CAKE_UniV3_3000, WBNB_CAKE_CakeV3_500, WBNB_ETH_UniV3_3000
        );

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(ETH.safeGetBalance({ account: user }), quoterAmountOut);
    }

    function test_multiswapRouterComponent_failedV3Swap() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        deal(USDC, user, 100e18);

        mData.amountIn = 100e18;
        mData.tokenIn = USDC;
        mData.pairs = Solarray.bytes32s(USDC_CAKE_UniV3_500);

        assertEq(quoter.multiswap({ data: mData }), 0);

        _resetPrank(user);
        USDC.safeApprove({ spender: address(factory), value: 100e18 });

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_FailedV3Swap.selector);
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }

    function test_multiswapRouterComponent_multiswap_failedV2Swap() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
        // wrong pair fee
         Solarray.bytes32s(0x0000000000000000000009c016b9a82891338f9bA80E2D6970FddA79D1eb0daE);

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_FailedV2Swap.selector);
        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }

    function test_multiswapRouterComponent_failedCallback() external {
        (, bytes memory data) =
            contracts.multiswapRouterComponent.call(abi.encodeWithSelector(TransferComponent.transferToken.selector));

        assertEq(bytes4(data), IMultiswapRouterComponent.MultiswapRouterComponent_SenderMustBeUniswapV3Pool.selector);
    }

    function test_multiswapRouterComponent_multiswap_shouldRevertIfAmountOutLtMinAmountOut() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
            Solarray.bytes32s(USDT_USDC_Cake, USDC_CAKE_Cake, BUSD_CAKE_Biswap, BUSD_ETH_Biswap, WBNB_ETH_Bakery);

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut + 1;

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountOut.selector);
        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }

    function test_multiswapRouterComponent_multiswap_shouldTransferAmountInToV2PairWhenBalanceIsGteAmountIn() external {
        deal(USDT, address(factory), 100e18);

        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs =
            Solarray.bytes32s(USDT_USDC_Cake, USDC_CAKE_Cake, BUSD_CAKE_Biswap, BUSD_ETH_Biswap, WBNB_ETH_Bakery);

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut;

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }

    // =========================
    // multiswap with native
    // =========================

    function test_multiswapRouterComponent_multiswap_multiswapNative() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        deal({ to: user, give: 10e18 });

        mData.amountIn = 10e18;
        mData.tokenIn = address(0);
        mData.pairs =
            Solarray.bytes32s(WBNB_ETH_Bakery, BUSD_ETH_Biswap, BUSD_CAKE_Biswap, USDC_CAKE_Cake, USDT_USDC_Cake);

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);

        uint256 userBalanceBefore = USDT.safeGetBalance({ account: user });

        factory.multicall{ value: 10e18 }({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(USDT.safeGetBalance({ account: user }) - userBalanceBefore, quoterAmountOut);
    }

    function test_multiswapRouterComponent_multiswap_swapToNativeThroughV2V3Pairs() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_Cake, BUSD_USDC_CakeV3_100, BUSD_CAKE_Cake, WBNB_CAKE_CakeV3_100);

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut * 0.98e18 / 1e18;

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        uint256 userBalanceBefore = user.balance;

        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.unwrapNativeAndTransferTo, (user))
            )
        });

        assertEq(user.balance - userBalanceBefore, quoterAmountOut);
    }

    // =========================
    // multiswap with fee
    // =========================

    function test_multiswapRouterComponent_multiswap_shouldCalculateFee() external {
        _resetPrank(owner);
        quoter.setFeeContract({ newFeeContract: address(feeContract) });
        // 0.03%
        feeContract.setProtocolFee({ newProtocolFee: 300 });

        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(
            ETH_USDT_UniV3_500, WBNB_ETH_UniV3_500, WBNB_CAKE_UniV3_3000, WBNB_CAKE_CakeV3_500, WBNB_ETH_UniV3_3000
        );

        uint256 quoterAmountOut = quoter.multiswap({ data: mData });

        mData.minAmountOut = quoterAmountOut;

        _resetPrank(user);
        uint256 nonce = ITransferComponent(address(factory)).getNonceForPermit2({ user: user });
        bytes memory signature = _permit2Sign(
            userPk,
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: USDT, amount: 100e18 }),
                nonce: nonce,
                deadline: block.timestamp
            })
        );

        _expectERC20TransferCall(ETH, address(feeContract), quoterAmountOut * 300 / (1e6 - 300));
        factory.multicall({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000024,
            data: Solarray.bytess(
                abi.encodeCall(TransferComponent.transferFromPermit2, (USDT, 100e18, nonce, block.timestamp, signature)),
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });

        assertEq(ETH.safeGetBalance({ account: user }), quoterAmountOut);
        assertEq(feeContract.profit({ owner: address(feeContract), token: ETH }), quoterAmountOut * 300 / (1e6 - 300));
    }

    // =========================
    // no transfer revert
    // =========================

    function test_multiswapRouterComponent_multiswap_noTransferRevert() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        deal({ token: USDT, to: address(factory), give: 100e18 });

        mData.amountIn = 100e18;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(
            ETH_USDT_UniV3_500, WBNB_ETH_UniV3_500, WBNB_CAKE_UniV3_3000, WBNB_CAKE_CakeV3_500, WBNB_ETH_UniV3_3000
        );

        _resetPrank(user);

        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        factory.multicall({
            data: Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (user))
            )
        });
    }
}
