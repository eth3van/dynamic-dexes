// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Quoter } from "../src/lens/Quoter.sol";

import { Factory } from "../src/Factory.sol";
import { Proxy, InitialImplementation } from "../src/proxy/Proxy.sol";
import { MultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { TransferComponent } from "../src/components/TransferComponent.sol";
import { StargateComponent } from "../src/components/bridges/StargateComponent.sol";

import { DeployEngine } from "./DeployEngine.sol";

import "../test/Helpers.t.sol";

contract Deploy is Script {
    address quoter = 0x46f4ce97aFd70cd668984C874795941E7Fc591CA;
    address quoterProxy = 0x51a85c557cD6Aa35880D55799849dDCD6c20B5Cd;

    address multiswapRouterComponent = 0x8973bdDC469c0CE56D9b41dA25C4f1b4D0c4DBa9;
    address transferComponent = 0x3BBcB05884ff9b8149E94FcfC7Bd013d18d12D2f;

    address proxy = 0x2Ea84370660448fd9017715f2F36727AE64f5Fe3;

    bool upgrade;

    bytes32 salt = keccak256("factory-salt-1");
    bytes32 quotersalt = keccak256("quoter-salt-1");

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        if (quoter == address(0)) {
            quoter = address(new Quoter(WBNB));

            if (quoterProxy == address(0)) {
                quoterProxy = address(new Proxy{ salt: quotersalt }(deployer));

                InitialImplementation(quoterProxy).upgradeTo(quoter, abi.encodeCall(Quoter.initialize, (deployer)));
            } else {
                Quoter(quoterProxy).upgradeTo(quoter);
            }
        }

        _deployImplemetations();

        if (upgrade) {
            address factory = DeployFactory.deployFactory(transferComponent, multiswapRouterComponent);

            if (proxy == address(0)) {
                proxy = address(new Proxy{ salt: salt }(deployer));

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
