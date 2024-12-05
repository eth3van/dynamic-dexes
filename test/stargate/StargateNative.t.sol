// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    BaseTest,
    IERC20,
    Solarray,
    IMultiswapRouterComponent,
    ITransferComponent,
    StargateComponent,
    IStargateComponent,
    TransferHelper
} from "../BaseTest.t.sol";

import "../Helpers.t.sol";

contract StargateComponentTest is BaseTest {
    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("ethereum"));

        _createUsers();

        _resetPrank(owner);

        deployForTest();

        deal({ to: user, give: 1000e18 });
    }

    // =========================
    // sendStargate with native
    // =========================

    address stargatePool = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931;
    uint16 dstEidV2 = 30_110;

    function test_stargateComponent_sendStargateNative_shouldSendStargateWithNativePool() external checkTokenStorage {
        _resetPrank(user);

        (uint256 fee,) = IStargateComponent(address(factory)).quoteV2({
            poolAddress: stargatePool,
            dstEid: dstEidV2,
            amountLD: 0.111111111111111111e18,
            composer: user,
            composeMsg: bytes(""),
            composeGasLimit: 0
        });

        assertGt(fee, 0.111111111111111111e18);

        factory.multicall{ value: fee }({
            replace: 0x0000000000000000000000000000000000000000000000000000000000000000,
            data: Solarray.bytess(
                abi.encodeCall(
                    IStargateComponent.sendStargateV2, (stargatePool, dstEidV2, 0.111111111111111111e18, user, 0, bytes(""))
                )
            )
        });

        assertEq(address(factory).balance, 0);
    }
}
