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
            multiswapRouterComponent: 0x96Fda36A350e40F89Bcdeb5149eFE4C77316F961,
            transferComponent: 0xbe35b0b10037e11a6D0A71c326FcF929935A4230,
            stargateComponent: 0x76126f040aF711bE697675137557524Ed79A280B,
            layerZeroComponent: 0xA2a3F952427c22e208a8298fd2346B8e664964b1,
            symbiosisComponent: 0xe9BEbFC505a738A58319F509EfB51A8ac6c8008f,
            //
            quoter: 0x3E1D733045E7abdC0bd28A272b45cC8896528bB2,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x15ad2B8844a7f42A94F37AdFc90BeeBd5D1c99AA,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xF307b0a60330512D51e4C8e4ddAA3E26D8f08569,
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
            multiswapRouterComponent: 0x2163682DCf72d01679136f3387E794D51cB006c7,
            transferComponent: 0xfDf7b550BD971dF0846872080cE93c67dE00853f,
            stargateComponent: 0xa19BFB487265190E387F099D1dA18F57B8986C4E,
            layerZeroComponent: 0xC2F6a6c1712899fCA57df645cfA0E9d04e0B5A38,
            symbiosisComponent: 0x92493CC018eA0d7c184cd9A0403Fa2d8729c5A02,
            //
            quoter: 0x490555CBa64d606FFf6f82a3A373cEA5d59B3973,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0xB3b674c653A43895fB5269D665A1De39ae8818d2,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xCc5bdcB370BDff54F92bEBF2EF7EE4cD049E45b0,
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
            multiswapRouterComponent: 0x194Fb60509a5c50905456b0A783A171D7E4Ed895,
            transferComponent: 0xFd431Bcc7D1aAc3166e7D6c328b21567c55AAfD0,
            stargateComponent: 0xA7c61a0aae5e3CC3484c13B86dD39ABa80E70940,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x48060BF6528b7896D16c83FbBda7F21566d6b014,
            //
            quoter: 0xaA2b8D9B4328076Ff656476111F5c654D1d70Eb0,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x490555CBa64d606FFf6f82a3A373cEA5d59B3973,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x71e1e613f57102A7c921a829848C3823030ed500,
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
            multiswapRouterComponent: 0xaA2b8D9B4328076Ff656476111F5c654D1d70Eb0,
            transferComponent: 0xc25bED344C4c3885f16d127F23FaDaa82784c2A6,
            stargateComponent: 0x0112d7bBa71214056EeDAAaC031ffA56CCf1471D,
            layerZeroComponent: 0xC0D032E84682c43e101E1e6578E0dEded5d224eD,
            symbiosisComponent: 0xB2C81d9cB2B3341eC5a7F42A89B59D282D8c848E,
            //
            quoter: 0x4FF57397049F32FB6A7c8EA65d7C1dA15b4e309B,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0xe536D069a426e8a8f90927e5BBf45e13Bd68f743,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xA429B21f896220510BA8FF26333A95a66F792621,
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
            multiswapRouterComponent: 0x463Bb4d10B9e9194fD8248DF9cE9c00075f645c2,
            transferComponent: 0xF9B37dFa8479C657FddD9fB50dDb75404622EBCe,
            stargateComponent: 0x62Fa7C88078BC1DE3C60A4D825891CB414C288f8,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x82eefc5d2053CC3C33d76F58979cAcd08944C2CC,
            //
            quoter: 0xf2A3Ca6cBFcF49389973FFB533180Ad82e31A180,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0xc25bED344C4c3885f16d127F23FaDaa82784c2A6,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xDa7fbeb9D9Ee83194f10E9D84Ad6DCb47A7311Dc,
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
            multiswapRouterComponent: 0x463Bb4d10B9e9194fD8248DF9cE9c00075f645c2,
            transferComponent: 0xF9B37dFa8479C657FddD9fB50dDb75404622EBCe,
            stargateComponent: 0x62Fa7C88078BC1DE3C60A4D825891CB414C288f8,
            layerZeroComponent: 0x10255Eb3cd67406b07D6C82E69460848BCa83022,
            symbiosisComponent: 0x82eefc5d2053CC3C33d76F58979cAcd08944C2CC,
            //
            quoter: 0xf2A3Ca6cBFcF49389973FFB533180Ad82e31A180,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0xc25bED344C4c3885f16d127F23FaDaa82784c2A6,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0xDa7fbeb9D9Ee83194f10E9D84Ad6DCb47A7311Dc,
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
            multiswapRouterComponent: 0x033D438b5a95216740F14e80b6Ce045C0E65d610,
            transferComponent: 0xdd4ec4bFecAb02CbE60CdBA8De49821a1105c24f,
            stargateComponent: 0x33E3337E3d68aB3b56C86613CCF34CB0d006Ab04,
            layerZeroComponent: 0x3E1D733045E7abdC0bd28A272b45cC8896528bB2,
            symbiosisComponent: 0x7559382f22a50e22d5c6026E04be5cd73Bcfa4c4,
            //
            quoter: 0xC2F6a6c1712899fCA57df645cfA0E9d04e0B5A38,
            quoterProxy: 0x13e6aC30fC8E37792F18b1e3D75B8266B0A93734,
            proxy: 0x9AE4De30ad3943e3b65E5DF41e8FB8CC0F0213d7,
            feeContract: 0x0BF76A83c92AAc1214C7F256A923863a37c40FBe,
            feeContractProxy: 0x20F282686b842851C8D7552d6fD095B55dBc775f,
            //
            prodFactory: 0x2ef78f53965cB6b6BE3DF79e143D07790c3E84b3,
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
            selectors[i++] = MultiswapRouterComponent.multiswap.selector;
            selectors[i++] = MultiswapRouterComponent.multiswap2.selector;
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
