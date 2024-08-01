// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Quoter } from "../src/lens/Quoter.sol";
import { Factory } from "../src/Factory.sol";

import { InitialImplementation, Proxy } from "../src/proxy/Proxy.sol";

import { DeployEngine, Contracts, getContracts } from "./DeployEngine.sol";

import { LayerZeroComponent } from "../src/components/bridges/LayerZeroComponent.sol";

contract Deploy is Script {
    bytes32 salt = keccak256("factory-salt-1");
    bytes32 quotersalt = keccak256("quoter-salt-1");

    // ===================

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        Contracts memory contracts = getContracts({ chainId: block.chainid });

        if (contracts.quoter == address(0)) {
            contracts.quoter = address(new Quoter({ wrappedNative_: contracts.wrappedNative }));

            if (contracts.quoterProxy == address(0)) {
                contracts.quoterProxy = address(new Proxy{ salt: quotersalt }({ initialOwner: deployer }));

                InitialImplementation(contracts.quoterProxy).upgradeTo({
                    implementation: contracts.quoter,
                    data: abi.encodeCall(Quoter.initialize, (deployer))
                });
            } else {
                Quoter(contracts.quoterProxy).upgradeTo({ newImplementation: contracts.quoter });
            }
        }

        bool upgrade;
        (contracts, upgrade) = DeployEngine.deployImplemetations({ contracts: contracts, isTest: false });

        if (upgrade) {
            address factory = DeployEngine.deployFactory({ contracts: contracts });

            if (contracts.proxy == address(0)) {
                contracts.proxy = address(new Proxy{ salt: salt }({ initialOwner: deployer }));

                bytes[] memory initCalls = new bytes[](0);

                InitialImplementation(contracts.proxy).upgradeTo({
                    implementation: factory,
                    data: abi.encodeCall(Factory.initialize, (deployer, initCalls))
                });
            } else {
                Factory(payable(contracts.proxy)).upgradeTo({ newImplementation: factory });
            }
        }

        LayerZeroComponent _layerZeroComponent = LayerZeroComponent(contracts.proxy);

        if (_layerZeroComponent.getDelegate() == address(0)) {
            _layerZeroComponent.setDelegate({ delegate: deployer });
        }
        if (_layerZeroComponent.defaultGasLimit() == 0) {
            _layerZeroComponent.setDefaultGasLimit({ newDefaultGasLimit: 50_000 });
        }

        vm.stopBroadcast();
    }
}
