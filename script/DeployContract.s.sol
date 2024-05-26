// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Factory } from "../src/Factory.sol";
import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { MultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../src/components/TransferComponent.sol";
import { StargateComponent } from "../src/components/bridges/StargateComponent.sol";

import { DeployEngine } from "./DeployEngine.sol";

import "../test/Helpers.t.sol";

contract Deploy is Script {
    address multiswapRouterComponent = address(1);
    address transferComponent = address(0);
    address stargateComponent = address(0);

    address proxy = 0x9d5b514435EE72bA227453E907835724Fff6715e;

    bytes32 salt = keccak256("dev_salt-2");

    // testnet
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    address arbStargateComposer = 0xb2d85b2484c910A6953D28De5D3B8d204f7DDf15;
    address bnbStargateComposer = 0x75D573607f5047C728D3a786BE3Ba33765712875;
    address sepStargateComposer = 0x4febD509277f485A5feB90fb20DC0D3FAe6Bf856;

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        _deployImplemetations();
        address factory = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent);

        if (proxy == address(0)) {
            proxy = address(new Proxy{ salt: salt }(deployer));

            InitialImplementation(proxy).upgradeTo(
                factory, abi.encodeCall(Factory.initialize, (deployer, new bytes[](0)))
            );
        } else {
            Factory(payable(proxy)).upgradeTo(factory);
        }

        vm.stopBroadcast();
    }

    function _deployImplemetations() internal {
        if (multiswapRouterComponent == address(0)) {
            multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        }

        if (transferComponent == address(0)) {
            transferComponent = address(new TransferComponent(WBNB));
        }

        if (stargateComponent == address(0)) {
            stargateComponent = address(
                new StargateComponent(
                    lzEndpoint,
                    block.chainid == 11_155_111
                        ? sepStargateComposer
                        : block.chainid == 97 ? bnbStargateComposer : arbStargateComposer
                )
            );
        }
    }
}

library DeployFactory {
    function deployFactory(address transferComponent, address multiswapRouterComponent) internal returns (address) {
        bytes4[] memory selectors = new bytes4[](250);
        address[] memory componentAddresses = new address[](250);

        uint256 i;
        uint256 j;

        if (transferComponent != address(0)) {
            // transfer Component
            selectors[i++] = TransferComponent.transferToken.selector;
            selectors[i++] = TransferComponent.transferNative.selector;
            selectors[i++] = TransferComponent.unwrapNativeAndTransferTo.selector;
            for (uint256 k; k < 3; ++k) {
                componentAddresses[j++] = transferComponent;
            }
        }

        if (multiswapRouterComponent != address(0)) {
            // multiswap Component
            selectors[i++] = MultiswapRouterComponent.wrappedNative.selector;
            selectors[i++] = MultiswapRouterComponent.feeContract.selector;
            selectors[i++] = MultiswapRouterComponent.setFeeContract.selector;
            selectors[i++] = MultiswapRouterComponent.multiswap.selector;
            selectors[i++] = MultiswapRouterComponent.partswap.selector;
            for (uint256 k; k < 5; ++k) {
                componentAddresses[j++] = multiswapRouterComponent;
            }
        }

        // TODO Stargate Component
        // selectors[i++] = StargateComponent.lzEndpoint.selector;
        // selectors[i++] = StargateComponent.stargateV1Composer.selector;
        // selectors[i++] = StargateComponent.quoteV1.selector;
        // selectors[i++] = StargateComponent.quoteV2.selector;
        // selectors[i++] = StargateComponent.sendStargateV1.selector;
        // selectors[i++] = StargateComponent.sendStargateV2.selector;
        // selectors[i++] = StargateComponent.sgReceive.selector;
        // selectors[i++] = StargateComponent.lzCompose.selector;
        // for (uint256 k; k < 8; ++k) {
        //     componentAddresses[j++] = stargateComponent;
        // }

        assembly {
            mstore(selectors, i)
            mstore(componentAddresses, j)
        }

        return address(new Factory(DeployEngine.getBytesArray(selectors, componentAddresses)));
    }
}
