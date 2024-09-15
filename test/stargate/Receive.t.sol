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

    function test_stargateComponent_lzCompose_shouldRevertIfSenderIsNotLzEndpoint() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 0;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_UniV3_100);

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(ITransferComponent.transferToken, (USDC, 0, user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData);

        _resetPrank(user);

        vm.expectRevert(IStargateComponent.NotLZEndpoint.selector);
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

    function test_stargateComponent_lzCompose_shouldLzCompose() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 0;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_UniV3_100);

        deal(USDT, address(factory), 995.1e18);

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(ITransferComponent.transferToken, (USDC, 0, user))
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

    function test_stargateComponent_lzCompose_shouldSendTokensToReceiverIfCallFailed() external {
        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(ITransferComponent.transferToken, (USDT, 0, user)),
                abi.encodeCall(ITransferComponent.transferToken, (USDT, 0, user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData);

        _resetPrank(contracts.layerZeroEndpointV2);

        _expectERC20TransferCall(USDT, user, 995.1e18);
        vm.expectEmit();
        emit CallFailed({ errorMessage: abi.encodeWithSelector(TransferHelper.TransferHelper_TransferError.selector) });
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

    function test_stargateComponent_lzCompose_shouldSendTokensToReceiverIfCallFailedWithNative() external {
        deal({ to: address(factory), give: 0.001e18 });

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(abi.encodeCall(ITransferComponent.transferToken, (USDC, 21, user)))
        );

        bytes memory composeMsg = abi.encode(
            address(0), user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData
        );

        _resetPrank(contracts.layerZeroEndpointV2);

        vm.expectEmit();
        emit CallFailed({ errorMessage: abi.encodeWithSelector(TransferHelper.TransferHelper_TransferError.selector) });
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
