// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { DeployEngine, Contracts, getContracts } from "../../script/DeployEngine.sol";

import { Solarray } from "solarray/Solarray.sol";

import { InitialImplementation, Proxy } from "../../src/proxy/Proxy.sol";

import { IFactory } from "../../src/Factory.sol";

import { IMultiswapRouterComponent } from "../../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { StargateComponent } from "../../src/components/bridges/StargateComponent.sol";

import { OFTComposeMsgCodec } from "../../src/components/bridges/libraries/OFTComposeMsgCodec.sol";

import "../Helpers.t.sol";

contract ReceiveStargateComponentTest is Test {
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

        vm.stopPrank();
    }

    // =========================
    // lzCompose
    // =========================

    function test_stargateComponent_laCompose_shouldLzCompose() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        mData.amountIn = 0;
        mData.tokenIn = USDT;
        mData.pairs = Solarray.bytes32s(USDT_USDC_UniV3_100);

        deal(USDT, address(bridge), 995.1e18);

        bytes memory multicallData = abi.encodeWithSignature(
            "multicall(bytes32,bytes[])",
            0x0000000000000000000000000000000000000000000000000000000000000024,
            Solarray.bytess(
                abi.encodeCall(IMultiswapRouterComponent.multiswap, (mData)),
                abi.encodeCall(TransferComponent.transferToken, (USDC, 0, user))
            )
        );

        bytes memory composeMsg =
            abi.encode(USDT, user, 0x00000000000000000000000000000000000000000000000000000000000000e8, multicallData);

        startHoax(contracts.endpointV2);

        StargateComponent(address(bridge)).lzCompose(
            user,
            0x0000000000000000000000000000000000000000000000000000000000240044,
            OFTComposeMsgCodec.encode(
                1, 30_101, 995.1e18, abi.encodePacked(hex"000000000000000000000000", bridge, composeMsg)
            ),
            contracts.endpointV2,
            bytes("")
        );
    }
}
