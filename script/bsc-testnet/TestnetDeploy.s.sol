// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Factory } from "../../src/Factory.sol";
import { Proxy, InitialImplementation } from "../../src/proxy/Proxy.sol";
import { MultiswapRouterComponent } from "../../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../../src/components/TransferComponent.sol";
import { StargateComponent } from "../../src/components/bridges/StargateComponent.sol";

import { DeployEngine } from "../DeployEngine.sol";

contract Deploy is Script {
    address multiswapRouterComponent = 0xFC08aCb8ab29159Cc864D7c7EC8AF2b611DE0820;
    address transferComponent = 0xd41B295F9695c3E90e845918aBB384D73a85C635;

    address stargateComponent = 0xB5fEB7A7241058509655F18246e2C9cd10B39626;

    address proxy = 0x29F4Bf32E90cAcb299fC82569670f670d334630a;

    bool upgrade;

    // ===================
    // helpers for multiswapComponent and transferComponent deployment
    // ===================

    address WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    // ===================
    // helpers for stargateComponent deployment
    // ===================

    // bnb testnet
    address endpointV2 = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address stargateComposerV1 = 0x75D573607f5047C728D3a786BE3Ba33765712875;

    // ===================

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        _deployImplemetations();

        if (upgrade) {
            address factory = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent, stargateComponent);

            if (proxy == address(0)) {
                proxy = address(new Proxy(deployer));

                bytes[] memory initCalls = new bytes[](0);

                InitialImplementation(proxy).upgradeTo(
                    factory, abi.encodeCall(Factory.initialize, (deployer, initCalls))
                );
            } else {
                Factory(payable(proxy)).upgradeTo(factory);
            }
        }

        vm.stopBroadcast();
    }

    function _deployImplemetations() internal {
        if (multiswapRouterComponent == address(0)) {
            upgrade = true;

            multiswapRouterComponent = address(new MultiswapRouterComponent(WBNB));
        }

        if (transferComponent == address(0)) {
            upgrade = true;

            transferComponent = address(new TransferComponent(WBNB));
        }

        if (stargateComponent == address(0)) {
            upgrade = true;

            stargateComponent = address(new StargateComponent(endpointV2, stargateComposerV1));
        }
    }
}

library DeployFactory {
    function deployFactory(
        address transferComponent,
        address multiswapRouterComponent,
        address stargateComponent
    )
        internal
        returns (address)
    {
        bytes4[] memory selectors = new bytes4[](250);
        address[] memory componentAddresses = new address[](250);

        uint256 i;
        uint256 j;

        if (transferComponent != address(0)) {
            // transfer Component
            selectors[i++] = TransferComponent.transferToken.selector;
            selectors[i++] = TransferComponent.transferNative.selector;
            selectors[i++] = TransferComponent.unwrapNative.selector;
            selectors[i++] = TransferComponent.unwrapNativeAndTransferTo.selector;
            for (uint256 k; k < 4; ++k) {
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

        if (stargateComponent != address(0)) {
            selectors[i++] = StargateComponent.lzEndpoint.selector;
            selectors[i++] = StargateComponent.stargateV1Composer.selector;
            selectors[i++] = StargateComponent.quoteV1.selector;
            selectors[i++] = StargateComponent.quoteV2.selector;
            selectors[i++] = StargateComponent.sendStargateV1.selector;
            selectors[i++] = StargateComponent.sendStargateV2.selector;
            selectors[i++] = StargateComponent.sgReceive.selector;
            selectors[i++] = StargateComponent.lzCompose.selector;
            for (uint256 k; k < 8; ++k) {
                componentAddresses[j++] = stargateComponent;
            }
        }

        assembly {
            mstore(selectors, i)
            mstore(componentAddresses, j)
        }

        return address(new Factory(DeployEngine.getBytesArray(selectors, componentAddresses)));
    }
}
