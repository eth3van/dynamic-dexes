// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Solarray } from "solarray/Solarray.sol";

import { DeployEngine, Contracts, getContracts } from "../script/DeployEngine.sol";

import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { IOwnable2Step, IOwnable } from "../src/external/IOwnable2Step.sol";
import { Ownable } from "../src/external/Ownable.sol";
import { TransferHelper } from "../src/components/libraries/TransferHelper.sol";

import { Quoter } from "../src/lens/Quoter.sol";

import { Factory, IFactory, Initializable } from "../src/Factory.sol";
import { FeeContract, IFeeContract } from "../src/FeeContract.sol";

import { MultiswapRouterComponent, IMultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { TransferComponent, ITransferComponent } from "../src/components/TransferComponent.sol";

import {
    StargateComponent,
    IStargateComponent,
    ILayerZeroComposer,
    OptionsBuilder,
    OFTComposeMsgCodec
} from "../src/components/bridges/StargateComponent.sol";
import { LayerZeroComponent, ILayerZeroComponent } from "../src/components/bridges/LayerZeroComponent.sol";

contract BaseTest is Test {
    address owner;
    address user;

    Factory factory;
    Quoter quoter;
    FeeContract feeContract;

    Contracts contracts;

    function deployForTest() internal {
        contracts = getContracts({ chainId: block.chainid });

        (contracts,) = DeployEngine.deployImplemetations({ contracts: contracts, isTest: true });

        quoter = Quoter(address(new Proxy({ initialOwner: owner })));
        InitialImplementation(address(quoter)).upgradeTo({
            implementation: address(new Quoter({ wrappedNative_: contracts.wrappedNative })),
            data: abi.encodeCall(Quoter.initialize, (owner))
        });

        factory = Factory(payable(address(new Proxy({ initialOwner: owner }))));
        feeContract = FeeContract(address(new Proxy({ initialOwner: owner })));

        InitialImplementation(address(feeContract)).upgradeTo({
            implementation: address(new FeeContract()),
            data: abi.encodeCall(FeeContract.initialize, (owner, address(factory)))
        });

        InitialImplementation(address(factory)).upgradeTo({
            implementation: DeployEngine.deployFactory({ contracts: contracts }),
            data: abi.encodeCall(
                IFactory.initialize,
                (owner, Solarray.bytess(abi.encodeCall(IMultiswapRouterComponent.setFeeContract, address(feeContract))))
            )
        });
    }

    // helper

    function _createUsers() internal {
        owner = makeAddr({ name: "owner" });
        user = makeAddr({ name: "user" });
    }

    function _resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }

    function _resetPrank(address msgSender, address origin) internal {
        vm.stopPrank();
        vm.startPrank(msgSender, origin);
    }

    function _expectERC20TransferCall(address token, address to, uint256 amount) internal {
        vm.expectCall(token, abi.encodeCall(IERC20.transfer, (to, amount)));
    }

    function _expectERC20ApproveCall(address token, address to, uint256 amount) internal {
        vm.expectCall(token, abi.encodeCall(IERC20.approve, (to, amount)));
    }

    function _expectERC20TransferFromCall(address token, address from, address to, uint256 amount) internal {
        vm.expectCall(token, abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
    }
}
