// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";
import { DeployEngine } from "../../script/DeployEngine.sol";
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
        vm.createSelectFork(vm.envString("BNB_RPC_URL"));

        deal(USDT, user, 1000e18);

        startHoax(owner);

        quoter = new Quoter(WBNB);

        multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        transferComponent = address(new TransferComponent(WBNB));

        factoryImplementation = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent);

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
    // multiswap
    // ==========================

    function test_multiswapRouterComponent_multiswap_shouldRevertIfMultiswapDataIsInvalid() external {
        IMultiswapRouterComponent.MultiswapCalldata memory mData;

        startHoax(user);

        // pairs array is empty
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidPairsArray.selector);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        // amountIn is 0
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        // tokenIn is address(0) (native) and msg.value < amountIn
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidAmountIn.selector);
        mData.amountIn = 1;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        // not approved
        vm.expectRevert(TransferHelper.TransferHelper_TransferFromError.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        IERC20(USDT).approve(address(router), 100e18);

        // tokenIn is not in sent pair
        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(WBNB_CAKE_CakeV3_500, BUSD_USDT_UniV3_3000);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        vm.expectRevert(IMultiswapRouterComponent.MultiswapRouterComponent_InvalidTokenIn.selector);
        mData.tokenIn = USDT;
        mData.amountIn = 100e18;
        mData.pairs = Solarray.bytes32s(BUSD_USDT_UniV3_3000, WBNB_CAKE_CakeV3_500);
        IMultiswapRouterComponent(address(router)).multiswap(mData);

        vm.stopPrank();
    }
}
