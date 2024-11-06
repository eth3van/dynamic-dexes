// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransferComponent } from "../src/components/TransferComponent.sol";
import { MultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { StargateComponent } from "../src/components/bridges/StargateComponent.sol";
import { LayerZeroComponent } from "../src/components/bridges/LayerZeroComponent.sol";
import { SymbiosisComponent } from "../src/components/bridges/SymbiosisComponent.sol";

import { Factory } from "../src/Factory.sol";

struct Contracts {
    address multiswapRouterComponent;
    address transferComponent;
    address stargateComponent;
    address layerZeroComponent;
    address symbiosisComponent;
    //
    address quoter;
    address quoterProxy;
    address proxy;
    address feeContract;
    address feeContractProxy;
    address prodFeeContractProxy;
    //
    address prodFactory;
    address prodProxy;
    //
    address wrappedNative;
    address layerZeroEndpointV2;
    address symbiosisPortal;
    address permit2;
    //
    address multisig;
}

address constant multisig = address(1);

function getContracts(uint256 chainId) pure returns (Contracts memory) {
    // ethereum
    if (chainId == 1) {
        return Contracts({
            multiswapRouterComponent: address(0),
            transferComponent: address(0),
            stargateComponent: address(0),
            layerZeroComponent: address(0),
            symbiosisComponent: address(0),
            //
            quoter: address(0),
            quoterProxy: address(0),
            proxy: address(0),
            feeContract: address(0),
            feeContractProxy: address(0),
            //
            prodFactory: address(0),
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0xb8f275fBf7A959F4BCE59999A2EF122A099e81A8,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // bnb
    if (chainId == 56) {
        return Contracts({
            multiswapRouterComponent: 0xfdF5F450CF0dE94F6C0Bf0B2355de1EEb753B39D,
            transferComponent: 0xe536D069a426e8a8f90927e5BBf45e13Bd68f743,
            stargateComponent: 0x194Fb60509a5c50905456b0A783A171D7E4Ed895,
            layerZeroComponent: 0xC2F6a6c1712899fCA57df645cfA0E9d04e0B5A38,
            symbiosisComponent: 0xFd431Bcc7D1aAc3166e7D6c328b21567c55AAfD0,
            //
            quoter: 0x2ef78f53965cB6b6BE3DF79e143D07790c3E84b3,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0xA41be65A7C167D401F8bD980ebb019AF5a7bfe26,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x71e1e613f57102A7c921a829848C3823030ed500,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0x5Aa5f7f84eD0E5db0a4a85C3947eA16B53352FD4,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // polygon
    if (chainId == 137) {
        return Contracts({
            multiswapRouterComponent: 0x14969B13A7Da9d2c25D94Dee70890A045e96F8Fb,
            transferComponent: 0x4FF57397049F32FB6A7c8EA65d7C1dA15b4e309B,
            stargateComponent: 0xE2D0C301c6293a2cA130AF2ACC47051e349079c5,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x463Bb4d10B9e9194fD8248DF9cE9c00075f645c2,
            //
            quoter: 0x33E3337E3d68aB3b56C86613CCF34CB0d006Ab04,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x911eEd36e5fB42d0202FAA2b0A848d35777eB05F,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x82eefc5d2053CC3C33d76F58979cAcd08944C2CC,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0xb8f275fBf7A959F4BCE59999A2EF122A099e81A8,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // avalanche
    if (chainId == 43_114) {
        return Contracts({
            multiswapRouterComponent: 0x605750a4e1d8971d64a7c4FD5f8DF238e06dFFc6,
            transferComponent: 0xC40D56c2cb35E7d0d4c1a5C313500C144b8f5AAD,
            stargateComponent: 0x2322D126382844B64E2FbDB1f69fe91A70Db463c,
            layerZeroComponent: 0xC0D032E84682c43e101E1e6578E0dEded5d224eD,
            symbiosisComponent: 0x66207F14770394CAEe61D68cB0BBB7E5b3A78426,
            //
            quoter: 0x33E3337E3d68aB3b56C86613CCF34CB0d006Ab04,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x861fF1De5877d91ebE37cE8fB95274524f5f8E21,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xFc204864E7E3a1a99504b39e18f5C7C57Eb4fEF7,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0xE75C7E85FE6ADd07077467064aD15847E6ba9877,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // optimism
    if (chainId == 10) {
        return Contracts({
            multiswapRouterComponent: 0x962056fe62f32B3C823e2E6B150bF142af26d93A,
            transferComponent: 0xDF1B257a5A188132ECFaB846d5E9c67Bc17aDA73,
            stargateComponent: 0x7877c8087F1E152a51162DAdfAA55dD4700279b6,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x72d012ede34937332Eabc80D1B9D2f995AC434c1,
            //
            quoter: 0x033D438b5a95216740F14e80b6Ce045C0E65d610,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x911eEd36e5fB42d0202FAA2b0A848d35777eB05F,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x2322D126382844B64E2FbDB1f69fe91A70Db463c,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0x4200000000000000000000000000000000000006,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0x292fC50e4eB66C3f6514b9E402dBc25961824D62,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // arbitrum
    if (chainId == 42_161) {
        return Contracts({
            multiswapRouterComponent: 0x962056fe62f32B3C823e2E6B150bF142af26d93A,
            transferComponent: 0xDF1B257a5A188132ECFaB846d5E9c67Bc17aDA73,
            stargateComponent: 0x7877c8087F1E152a51162DAdfAA55dD4700279b6,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x72d012ede34937332Eabc80D1B9D2f995AC434c1,
            //
            quoter: 0x033D438b5a95216740F14e80b6Ce045C0E65d610,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x911eEd36e5fB42d0202FAA2b0A848d35777eB05F,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x2322D126382844B64E2FbDB1f69fe91A70Db463c,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0x01A3c8E513B758EBB011F7AFaf6C37616c9C24d9,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // base
    if (chainId == 8453) {
        return Contracts({
            multiswapRouterComponent: 0xa6a39188097bc275593dDb875705491A70DBEC0B,
            transferComponent: 0x995f1B46F71Bc83a90653286e85185D27956687e,
            stargateComponent: 0x48229df22D71eecFf545A3698ACbacc5CF41D658,
            layerZeroComponent: 0x3E1D733045E7abdC0bd28A272b45cC8896528bB2,
            symbiosisComponent: 0x649BC4A713de188d4e68977ad61f9A5AD795D276,
            //
            quoter: 0xaEf92a53BBC3dd743C7Be3f5Edc1BDE10D8211e9,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x76126f040aF711bE697675137557524Ed79A280B,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xC0D032E84682c43e101E1e6578E0dEded5d224eD,
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0x4200000000000000000000000000000000000006,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0xEE981B2459331AD268cc63CE6167b446AF4161f8,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    // tron
    if (chainId /* 728126428 testnet */ == 2_494_104_990) {
        return Contracts({
            multiswapRouterComponent: address(0),
            transferComponent: address(0),
            stargateComponent: address(0),
            layerZeroComponent: address(0),
            symbiosisComponent: address(0),
            //
            quoter: address(0),
            quoterProxy: address(0),
            proxy: address(0),
            feeContract: address(0),
            feeContractProxy: address(0),
            //
            prodFactory: address(0),
            prodProxy: address(0),
            prodFeeContractProxy: address(0),
            //
            wrappedNative: 0x4200000000000000000000000000000000000006,
            layerZeroEndpointV2: 0x1a44076050125825900e736c501f859c50fE728c,
            symbiosisPortal: 0xd83B5752b42856a08087748dE6095af0bE52d299,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            //
            multisig: multisig
        });
    }

    Contracts memory c;
    return c;
}

library DeployEngine {
    function deployFactory(Contracts memory contracts) internal returns (address) {
        bytes4[] memory selectors = new bytes4[](250);
        address[] memory componentAddresses = new address[](25);
        uint256[] memory addressIndexes = new uint256[](250);

        uint256 i;
        uint256 j;
        uint256 addressIndex;
        uint256 iCache;

        if (contracts.transferComponent != address(0)) {
            // transfer Component
            selectors[i++] = TransferComponent.getNonceForPermit2.selector;
            selectors[i++] = TransferComponent.transferFromPermit2.selector;
            selectors[i++] = TransferComponent.transferToken.selector;
            selectors[i++] = TransferComponent.unwrapNativeAndTransferTo.selector;
            for (uint256 k; k < i - iCache; ++k) {
                addressIndexes[j++] = addressIndex;
            }
            iCache = i;
            componentAddresses[addressIndex] = contracts.transferComponent;
            ++addressIndex;
        }

        if (contracts.multiswapRouterComponent != address(0)) {
            // multiswap Component
            selectors[i++] = MultiswapRouterComponent.wrappedNative.selector;
            selectors[i++] = MultiswapRouterComponent.feeContract.selector;
            selectors[i++] = MultiswapRouterComponent.setFeeContract.selector;
            selectors[i++] = MultiswapRouterComponent.multiswap.selector;
            selectors[i++] = MultiswapRouterComponent.partswap.selector;
            for (uint256 k; k < i - iCache; ++k) {
                addressIndexes[j++] = addressIndex;
            }
            iCache = i;
            componentAddresses[addressIndex] = contracts.multiswapRouterComponent;
            ++addressIndex;
        }

        if (contracts.stargateComponent != address(0)) {
            selectors[i++] = StargateComponent.lzEndpoint.selector;
            selectors[i++] = StargateComponent.quoteV2.selector;
            selectors[i++] = StargateComponent.sendStargateV2.selector;
            selectors[i++] = StargateComponent.lzCompose.selector;
            for (uint256 k; k < i - iCache; ++k) {
                addressIndexes[j++] = addressIndex;
            }
            iCache = i;
            componentAddresses[addressIndex] = contracts.stargateComponent;
            ++addressIndex;
        }

        if (contracts.layerZeroComponent != address(0)) {
            selectors[i++] = LayerZeroComponent.eid.selector;
            selectors[i++] = LayerZeroComponent.defaultGasLimit.selector;
            selectors[i++] = LayerZeroComponent.getPeer.selector;
            selectors[i++] = LayerZeroComponent.getGasLimit.selector;
            selectors[i++] = LayerZeroComponent.getDelegate.selector;
            selectors[i++] = LayerZeroComponent.getUlnConfig.selector;
            selectors[i++] = LayerZeroComponent.getNativeSendCap.selector;
            selectors[i++] = LayerZeroComponent.isSupportedEid.selector;
            selectors[i++] = LayerZeroComponent.estimateFee.selector;
            selectors[i++] = LayerZeroComponent.sendDeposit.selector;
            selectors[i++] = LayerZeroComponent.setPeers.selector;
            selectors[i++] = LayerZeroComponent.setGasLimit.selector;
            selectors[i++] = LayerZeroComponent.setDefaultGasLimit.selector;
            selectors[i++] = LayerZeroComponent.setDelegate.selector;
            selectors[i++] = LayerZeroComponent.setUlnConfigs.selector;
            selectors[i++] = LayerZeroComponent.nextNonce.selector;
            selectors[i++] = LayerZeroComponent.allowInitializePath.selector;
            selectors[i++] = LayerZeroComponent.lzReceive.selector;
            for (uint256 k; k < i - iCache; ++k) {
                addressIndexes[j++] = addressIndex;
            }
            iCache = i;
            componentAddresses[addressIndex] = contracts.layerZeroComponent;
            ++addressIndex;
        }

        if (contracts.symbiosisComponent > address(1)) {
            selectors[i++] = SymbiosisComponent.portal.selector;
            selectors[i++] = SymbiosisComponent.sendSymbiosis.selector;
            for (uint256 k; k < i - iCache; ++k) {
                addressIndexes[j++] = addressIndex;
            }
            iCache = i;
            componentAddresses[addressIndex] = contracts.symbiosisComponent;
            ++addressIndex;
        }

        assembly {
            mstore(selectors, i)
            mstore(addressIndexes, j)
            mstore(componentAddresses, addressIndex)
        }

        return address(
            new Factory({
                componentsAndSelectors: getBytesArray({
                    selectors: selectors,
                    addressIndexes: addressIndexes,
                    componentAddresses: componentAddresses
                })
            })
        );
    }

    function deployImplementations(
        Contracts memory contracts,
        bool isTest
    )
        internal
        returns (Contracts memory, bool upgrade)
    {
        if (contracts.multiswapRouterComponent == address(0) || isTest) {
            upgrade = true;

            contracts.multiswapRouterComponent =
                address(new MultiswapRouterComponent({ wrappedNative_: contracts.wrappedNative }));
        }

        if (contracts.transferComponent == address(0) || isTest) {
            upgrade = true;

            contracts.transferComponent =
                address(new TransferComponent({ wrappedNative: contracts.wrappedNative, permit2: contracts.permit2 }));
        }

        if (contracts.stargateComponent == address(0) || isTest) {
            upgrade = true;

            contracts.stargateComponent = address(new StargateComponent({ endpointV2: contracts.layerZeroEndpointV2 }));
        }

        if (contracts.layerZeroComponent == address(0) || isTest) {
            upgrade = true;

            contracts.layerZeroComponent = address(new LayerZeroComponent({ endpointV2: contracts.layerZeroEndpointV2 }));
        }

        if (contracts.symbiosisComponent == address(0) || isTest) {
            upgrade = true;

            contracts.symbiosisComponent = address(new SymbiosisComponent({ portal_: contracts.symbiosisPortal }));
        }

        return (contracts, upgrade);
    }

    function getBytesArray(
        bytes4[] memory selectors,
        uint256[] memory addressIndexes,
        address[] memory componentAddresses
    )
        internal
        pure
        returns (bytes memory logicsAndSelectors)
    {
        quickSort(selectors, addressIndexes);

        uint256 selectorsLength = selectors.length;
        if (selectorsLength != addressIndexes.length) {
            revert("length of selectors and addressIndexes must be equal");
        }

        if (selectorsLength > 0) {
            uint256 length;

            unchecked {
                length = selectorsLength - 1;
            }

            // check that the selectors are sorted and there's no repeating
            for (uint256 i; i < length;) {
                unchecked {
                    if (selectors[i] >= selectors[i + 1]) {
                        revert("selectors must be sorted and there's no repeating");
                    }

                    ++i;
                }
            }
        }

        uint256 addressesLength = componentAddresses.length;
        unchecked {
            logicsAndSelectors = new bytes(4 + selectorsLength * 5 + addressesLength * 20);
        }

        assembly ("memory-safe") {
            let selectorAndAddressIndexValue
            // offset in memory to the beginning of selectors array values
            selectors := add(selectors, 32)
            // offset in memory to beginning of addressIndexes array values
            addressIndexes := add(addressIndexes, 32)
            // offset in memory to beginning of logicsAndSelectors bytes
            let logicsAndSelectorsOffset := add(logicsAndSelectors, 32)

            // write metadata -> selectors array length and addresses offset
            mstore(logicsAndSelectorsOffset, shl(224, add(shl(16, selectorsLength), mul(selectorsLength, 5))))
            logicsAndSelectorsOffset := add(logicsAndSelectorsOffset, 4)

            for { } selectorsLength {
                // post actions
                selectorsLength := sub(selectorsLength, 1)
                selectors := add(selectors, 32)
                addressIndexes := add(addressIndexes, 32)
                logicsAndSelectorsOffset := add(logicsAndSelectorsOffset, 5)
            } {
                // value creation:
                // 0xaaaaaaaaff000000000000000000000000000000000000000000000000000000
                selectorAndAddressIndexValue := or(mload(selectors), shl(216, mload(addressIndexes)))
                // store the value in the logicsAndSelectors byte array
                mstore(logicsAndSelectorsOffset, selectorAndAddressIndexValue)
            }

            for {
                // offset in memory to the beginning of componentAddresses array values
                componentAddresses := add(componentAddresses, 32)
            } addressesLength {
                // post actions
                addressesLength := sub(addressesLength, 1)
                componentAddresses := add(componentAddresses, 32)
                logicsAndSelectorsOffset := add(logicsAndSelectorsOffset, 20)
            } {
                // store the address in the logicsAndSelectors byte array
                mstore(logicsAndSelectorsOffset, shl(96, mload(componentAddresses)))
            }
        }
    }

    function quickSort(bytes4[] memory selectors, uint256[] memory addressIndexes) internal pure {
        if (selectors.length <= 1) {
            return;
        }

        int256 low;
        int256 high = int256(selectors.length - 1);
        int256[] memory stack = new int256[](selectors.length);
        int256 top = -1;

        ++top;
        stack[uint256(top)] = low;
        ++top;
        stack[uint256(top)] = high;

        while (top >= 0) {
            high = stack[uint256(top)];
            --top;
            low = stack[uint256(top)];
            --top;

            int256 pivotIndex = _partition(selectors, addressIndexes, low, high);

            if (pivotIndex - 1 > low) {
                ++top;
                stack[uint256(top)] = low;
                ++top;
                stack[uint256(top)] = pivotIndex - 1;
            }

            if (pivotIndex + 1 < high) {
                ++top;
                stack[uint256(top)] = pivotIndex + 1;
                ++top;
                stack[uint256(top)] = high;
            }
        }
    }

    function _partition(
        bytes4[] memory selectors,
        uint256[] memory addressIndexes,
        int256 low,
        int256 high
    )
        internal
        pure
        returns (int256)
    {
        bytes4 pivot = selectors[uint256(high)];
        int256 i = low - 1;

        for (int256 j = low; j < high; ++j) {
            if (selectors[uint256(j)] <= pivot) {
                i++;
                (selectors[uint256(i)], selectors[uint256(j)]) = (selectors[uint256(j)], selectors[uint256(i)]);

                if (addressIndexes.length == selectors.length) {
                    (addressIndexes[uint256(i)], addressIndexes[uint256(j)]) =
                        (addressIndexes[uint256(j)], addressIndexes[uint256(i)]);
                }
            }
        }

        (selectors[uint256(i + 1)], selectors[uint256(high)]) = (selectors[uint256(high)], selectors[uint256(i + 1)]);

        if (addressIndexes.length == selectors.length) {
            (addressIndexes[uint256(i + 1)], addressIndexes[uint256(high)]) =
                (addressIndexes[uint256(high)], addressIndexes[uint256(i + 1)]);
        }

        return i + 1;
    }
}
