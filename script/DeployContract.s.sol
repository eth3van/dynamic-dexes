// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Quoter } from "../src/lens/Quoter.sol";
import { Factory } from "../src/Factory.sol";

import { InitialImplementation, Proxy } from "../src/proxy/Proxy.sol";

import { DeployEngine, Contracts, getContracts } from "./DeployEngine.sol";

import { FeeContract } from "../src/FeeContract.sol";

import { MultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { LayerZeroComponent } from "../src/components/bridges/LayerZeroComponent.sol";

import { IOwnable2Step } from "../src/external/IOwnable2Step.sol";

contract Deploy is Script {
    bytes32 constant salt = keccak256("factory-salt-1");
    bytes32 constant quoterSalt = keccak256("quoter-salt-1");
    bytes32 constant feeContractSalt = keccak256("fee-contract-salt-1");

    bytes32 constant prodSalt = keccak256("prod-factory-salt-1");
    bytes32 constant prodFeeContractSalt = keccak256("prod-fee-contract-salt-1");

    // ===================

    function run() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        Contracts memory contracts = getContracts({ chainId: block.chainid });

        if (contracts.quoter == address(0)) {
            contracts.quoter = address(new Quoter({ wrappedNative_: contracts.wrappedNative }));

            if (contracts.quoterProxy == address(0)) {
                contracts.quoterProxy = address(new Proxy{ salt: quoterSalt }({ initialOwner: deployer }));

                InitialImplementation(contracts.quoterProxy).upgradeTo({
                    implementation: contracts.quoter,
                    data: abi.encodeCall(Quoter.initialize, (deployer))
                });
            } else {
                Quoter(contracts.quoterProxy).upgradeTo({ newImplementation: contracts.quoter });
            }
        }

        bool upgrade;
        (contracts, upgrade) = DeployEngine.deployImplementations({ contracts: contracts, isTest: false });
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

        if (contracts.feeContract == address(0)) {
            contracts.feeContract = address(new FeeContract());

            if (contracts.feeContractProxy == address(0)) {
                contracts.feeContractProxy = address(new Proxy{ salt: feeContractSalt }({ initialOwner: deployer }));

                InitialImplementation(contracts.feeContractProxy).upgradeTo({
                    implementation: contracts.feeContract,
                    data: abi.encodeCall(FeeContract.initialize, (deployer, contracts.proxy))
                });
            } else {
                FeeContract(payable(contracts.feeContractProxy)).upgradeTo({ newImplementation: contracts.feeContract });
            }
        }

        if (FeeContract(payable(contracts.feeContractProxy)).fees() == 0) {
            // 0.03%
            FeeContract(payable(contracts.feeContractProxy)).setProtocolFee({ newProtocolFee: 300 });
        }

        LayerZeroComponent _layerZeroComponent = LayerZeroComponent(contracts.proxy);

        if (_layerZeroComponent.getDelegate() == address(0)) {
            _layerZeroComponent.setDelegate({ delegate: deployer });
        }
        if (_layerZeroComponent.defaultGasLimit() == 0) {
            _layerZeroComponent.setDefaultGasLimit({ newDefaultGasLimit: 50_000 });
        }

        if (Factory(payable(contracts.proxy)).getFeeContractAddress() == address(0)) {
            Factory(payable(contracts.proxy)).setFeeContractAddress({ feeContractAddress: contracts.feeContractProxy });
        }

        if (Quoter(contracts.quoterProxy).getFeeContract() == address(0)) {
            Quoter(contracts.quoterProxy).setFeeContract({ newFeeContract: contracts.feeContractProxy });
        }

        vm.stopBroadcast();
    }

    function runProd() external {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer);

        Contracts memory contracts = getContracts({ chainId: block.chainid });

        if (contracts.quoter == address(0)) {
            contracts.quoter = address(new Quoter({ wrappedNative_: contracts.wrappedNative }));

            if (contracts.quoterProxy == address(0)) {
                contracts.quoterProxy = address(new Proxy{ salt: quoterSalt }({ initialOwner: deployer }));

                InitialImplementation(contracts.quoterProxy).upgradeTo({
                    implementation: contracts.quoter,
                    data: abi.encodeCall(Quoter.initialize, (deployer))
                });
            }
        }

        address factory = contracts.prodFactory;
        if (contracts.prodFactory == address(0)) {
            (contracts,) = DeployEngine.deployImplementations({ contracts: contracts, isTest: false });
            factory = DeployEngine.deployFactory({ contracts: contracts });
        }

        if (contracts.prodProxy == address(0)) {
            contracts.prodProxy = address(new Proxy{ salt: prodSalt }({ initialOwner: deployer }));

            bytes[] memory initCalls = new bytes[](0);

            InitialImplementation(contracts.prodProxy).upgradeTo({
                implementation: factory,
                data: abi.encodeCall(Factory.initialize, (deployer, initCalls))
            });
        }

        if (contracts.feeContract == address(0)) {
            contracts.feeContract = address(new FeeContract());
        }

        if (contracts.prodFeeContractProxy == address(0)) {
            contracts.prodFeeContractProxy = address(new Proxy{ salt: prodFeeContractSalt }({ initialOwner: deployer }));

            InitialImplementation(contracts.prodFeeContractProxy).upgradeTo({
                implementation: contracts.feeContract,
                data: abi.encodeCall(FeeContract.initialize, (deployer, contracts.prodProxy))
            });
        }

        if (FeeContract(payable(contracts.prodFeeContractProxy)).fees() == 0) {
            // 0.03%
            FeeContract(payable(contracts.prodFeeContractProxy)).setProtocolFee({ newProtocolFee: 300 });
        }

        LayerZeroComponent _layerZeroComponent = LayerZeroComponent(contracts.prodProxy);

        if (_layerZeroComponent.getDelegate() == address(0)) {
            _layerZeroComponent.setDelegate({ delegate: contracts.multisig });
        }
        if (_layerZeroComponent.defaultGasLimit() == 0) {
            _layerZeroComponent.setDefaultGasLimit({ newDefaultGasLimit: 50_000 });
        }

        if (Factory(payable(contracts.prodProxy)).getFeeContractAddress() == address(0)) {
            Factory(payable(contracts.prodProxy)).setFeeContractAddress({
                feeContractAddress: contracts.prodFeeContractProxy
            });
        }

        IOwnable2Step(contracts.prodProxy).transferOwnership({ newOwner: contracts.multisig });
        IOwnable2Step(contracts.prodFeeContractProxy).transferOwnership({ newOwner: contracts.multisig });

        console2.log("dexContract", contracts.prodProxy);
        console2.log("feeContract", contracts.prodFeeContractProxy);

        vm.stopBroadcast();
    }
}
