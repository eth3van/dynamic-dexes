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

    address proxy = 0x387f7c5A79bCb3B5C281c505b39fd48Cec0B814C;

    bytes32 salt = keccak256("dev_salt-1");

    // testnet
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        _deployImplemetations();
        address factory = _deployFactory();

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
            transferComponent = address(new TransferComponent());
        }

        if (stargateComponent == address(0)) {
            // TODO
            stargateComponent = address(new StargateComponent(lzEndpoint, lzEndpoint));
        }
    }

    function _deployFactory() internal returns (address) {
        bytes4[] memory selectors = new bytes4[](250);
        address[] memory componentAddresses = new address[](250);

        uint256 i;
        uint256 j;

        // ERC20 Component
        selectors[i++] = TransferComponent.transfer.selector;
        selectors[i++] = TransferComponent.transferNative.selector;
        componentAddresses[j++] = transferComponent;
        componentAddresses[j++] = transferComponent;

        if (multiswapRouterComponent != address(1)) {
            // Multiswap Component
            selectors[i++] = MultiswapRouterComponent.wrappedNative.selector;
            selectors[i++] = MultiswapRouterComponent.feeContract.selector;
            selectors[i++] = MultiswapRouterComponent.setFeeContract.selector;
            selectors[i++] = MultiswapRouterComponent.multiswap.selector;
            selectors[i++] = MultiswapRouterComponent.partswap.selector;
            for (uint256 k; k < 5; ++k) {
                componentAddresses[j++] = multiswapRouterComponent;
            }
        }

        // Stargate Component
        selectors[i++] = StargateComponent.lzEndpoint.selector;
        selectors[i++] = StargateComponent.stargateEndpoint.selector;
        selectors[i++] = StargateComponent.prepareTransferAndCall.selector;
        selectors[i++] = StargateComponent.sendStargate.selector;
        selectors[i++] = StargateComponent.lzCompose.selector;
        for (uint256 k; k < 5; ++k) {
            componentAddresses[j++] = stargateComponent;
        }

        assembly {
            mstore(selectors, i)
            mstore(componentAddresses, j)
        }

        return address(new Factory(DeployEngine.getBytesArray(selectors, componentAddresses)));
    }
}
