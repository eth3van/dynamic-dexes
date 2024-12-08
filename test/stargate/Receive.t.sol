// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    BaseTest,
    Solarray,
    IMultiswapRouterComponent,
    ITransferComponent,
    IStargateComponent,
    ILayerZeroComposer,
    OFTComposeMsgCodec,
    TransferHelper
} from "../BaseTest.t.sol";

import "../Helpers.t.sol";

contract ReceiveStargateComponentTest is BaseTest {
    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("bsc"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        deal({ token: USDT, to: address(factory), give: 995.1e18 });
    }

    // =========================
    // lzCompose
    // =========================

    function test_stargateComponent_lzCompose_shouldRevertIfSenderIsNotLzEndpoint() external checkTokenStorage {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 0;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_UniV3_100);

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(ITransferComponent.transferToken, (user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData);

        _resetPrank(user);

        vm.expectRevert(IStargateComponent.StargateComponent_NotLZEndpoint.selector);
        ILayerZeroComposer(address(factory)).lzCompose({
            _from: user,
            _guid: bytes32(uint256(1)),
            _message: OFTComposeMsgCodec.encode({
                _nonce: 1,
                _srcEid: 30_101,
                _amountLD: 995.1e18,
                _composeMsg: abi.encodePacked(hex"000000000000000000000000", factory, composeMsg)
            }),
            _executor: contracts.layerZeroEndpointV2,
            _extraData: bytes("")
        });
    }

    function test_stargateComponent_lzCompose_shouldLzCompose() external checkTokenStorage {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 0;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_CAKE_Cake);

        deal(USDT, address(factory), 995.1e18);

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(ITransferComponent.transferToken, (user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData);

        _resetPrank(contracts.layerZeroEndpointV2);

        ILayerZeroComposer(address(factory)).lzCompose({
            _from: user,
            _guid: bytes32(uint256(1)),
            _message: OFTComposeMsgCodec.encode({
                _nonce: 1,
                _srcEid: 30_101,
                _amountLD: 995.1e18,
                _composeMsg: abi.encodePacked(hex"000000000000000000000000", factory, composeMsg)
            }),
            _executor: contracts.layerZeroEndpointV2,
            _extraData: bytes("")
        });
    }

    event CallFailed(bytes errorMessage);

    function test_stargateComponent_lzCompose_shouldSendTokensToReceiverIfCallFailed() external checkTokenStorage {
        _resetPrank(owner);
        feeContract.setProtocolFee({ newProtocolFee: 300 });

        IMultiswapRouterComponent.Multiswap2Calldata memory m2Data;

        m2Data.fullAmount = 10e18;
        m2Data.amountInPercentages = Solarray.uint256s(0.1e18, 0.2e18, 0.3e18, 0.4e18);
        m2Data.tokenIn = USDT;
        m2Data.pairs = Solarray.bytes32Arrays(
            Solarray.bytes32s(USDT_USDC_Biswap),
            Solarray.bytes32s(USDT_USDC_Bakery),
            Solarray.bytes32s(USDT_USDC_Cake),
            Solarray.bytes32s(USDT_USDC_UniV3_100)
        );
        m2Data.tokenOut = USDC;

        uint256 quoterAmountOut = quoter.multiswap2({ data: m2Data });

        m2Data.minAmountOut = quoterAmountOut + 1;

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000000,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap2, (m2Data)),
                abi.encodeCall(ITransferComponent.transferToken, (user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x0000000000000000000000000000000000000000000000000000000000000000, multicallData);

        _resetPrank(contracts.layerZeroEndpointV2);

        _expectERC20TransferCall(USDT, user, 995.1e18 * (1_000_000 - 300) / 1_000_000);
        _expectERC20TransferCall(USDT, address(feeContract), 995.1e18 * 300 / 1_000_000);
        vm.expectEmit();
        emit CallFailed({
            errorMessage: abi.encodeWithSelector(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountOut.selector)
        });
        ILayerZeroComposer(address(factory)).lzCompose({
            _from: user,
            _guid: bytes32(uint256(1)),
            _message: OFTComposeMsgCodec.encode({
                _nonce: 1,
                _srcEid: 30_101,
                _amountLD: 995.1e18,
                _composeMsg: abi.encodePacked(hex"000000000000000000000000", factory, composeMsg)
            }),
            _executor: contracts.layerZeroEndpointV2,
            _extraData: bytes("")
        });
    }

    event TransferNative(address to) anonymous;

    function test_stargateComponent_lzCompose_shouldSendTokensToReceiverIfCallFailedWithNative()
        external
        checkTokenStorage
    {
        _resetPrank(owner);
        feeContract.setProtocolFee({ newProtocolFee: 300 });

        deal({ to: address(factory), give: 0.001e18 });

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(abi.encodeCall(ITransferComponent.unwrapNativeAndTransferTo, (user)))
        );

        bytes memory composeMsg = abi.encode(
            address(0), user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData
        );

        _resetPrank(contracts.layerZeroEndpointV2);

        vm.expectEmitAnonymous();
        emit TransferNative({ to: address(feeContract) });
        vm.expectEmit();
        emit CallFailed({ errorMessage: new bytes(0) });
        vm.expectEmitAnonymous();
        emit TransferNative({ to: user });
        ILayerZeroComposer(address(factory)).lzCompose({
            _from: user,
            _guid: bytes32(uint256(1)),
            _message: OFTComposeMsgCodec.encode({
                _nonce: 1,
                _srcEid: 30_101,
                _amountLD: 0.001e18,
                _composeMsg: abi.encodePacked(hex"000000000000000000000000", factory, composeMsg)
            }),
            _executor: contracts.layerZeroEndpointV2,
            _extraData: bytes("")
        });

        assertEq(address(factory).balance, 0);
    }
}
