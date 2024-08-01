// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransferComponent } from "../src/components/TransferComponent.sol";
import { MultiswapRouterComponent } from "../src/components/MultiswapRouterComponent.sol";
import { StargateComponent } from "../src/components/bridges/StargateComponent.sol";
import { LayerZeroComponent } from "../src/components/bridges/LayerZeroComponent.sol";

import { Factory } from "../src/Factory.sol";

struct Contracts {
    address transferComponent;
    address multiswapRouterComponent;
    address stargateComponent;
    address layerZeroComponent;
    //
    address quoter;
    address quoterProxy;
    address proxy;
    //
    address wrappedNative;
    address endpointV2;
}

function getContracts(uint256 chainId) pure returns (Contracts memory) {
    // ethereum
    if (chainId == 1) {
        return Contracts({
            transferComponent: address(0),
            multiswapRouterComponent: address(0),
            stargateComponent: address(0),
            layerZeroComponent: address(0),
            //
            quoter: address(0),
            quoterProxy: address(0),
            proxy: address(0),
            //
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            endpointV2: 0x1a44076050125825900e736c501f859c50fE728c
        });
    }

    // bnb
    if (chainId == 56) {
        return Contracts({
            transferComponent: 0x63C870276Ba8f7dC248B89320a7d24f938B5F14C,
            multiswapRouterComponent: 0xaA0e646040eC978059E835764E594af3A130f5Ac,
            stargateComponent: 0xB1368ce5FF0b927F62C41226c630083a8Ea259EF,
            layerZeroComponent: 0x285297B6c29F67baa92b2333FCcBE906917b7137,
            //
            quoter: 0x46f4ce97aFd70cd668984C874795941E7Fc591CA,
            quoterProxy: 0x51a85c557cD6Aa35880D55799849dDCD6c20B5Cd,
            proxy: 0x2Ea84370660448fd9017715f2F36727AE64f5Fe3,
            //
            wrappedNative: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            endpointV2: 0x1a44076050125825900e736c501f859c50fE728c
        });
    }

    // polygon
    if (chainId == 137) {
        return Contracts({
            transferComponent: 0x29F4Bf32E90cAcb299fC82569670f670d334630a,
            multiswapRouterComponent: 0xD4366D4b3af01111a9a3c97c0dfEdc44A3e8C2cF,
            stargateComponent: 0x29588c2cd38631d3892b3d6B7D0CB0Ad342067F0,
            layerZeroComponent: 0xd4f528eC9D963467F3ED1f51CB4e197e88c8eBA3,
            //
            quoter: 0xFC08aCb8ab29159Cc864D7c7EC8AF2b611DE0820,
            quoterProxy: 0x51a85c557cD6Aa35880D55799849dDCD6c20B5Cd,
            proxy: 0x2Ea84370660448fd9017715f2F36727AE64f5Fe3,
            //
            wrappedNative: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            endpointV2: 0x1a44076050125825900e736c501f859c50fE728c
        });
    }

    Contracts memory c;
    return c;
}

library DeployEngine {
    function deployFactory(Contracts memory contracts) internal returns (address) {
        bytes4[] memory selectors = new bytes4[](250);
        address[] memory componentAddresses = new address[](250);

        uint256 i;
        uint256 j;

        if (contracts.transferComponent != address(0)) {
            // transfer Component
            selectors[i++] = TransferComponent.transferToken.selector;
            selectors[i++] = TransferComponent.transferNative.selector;
            selectors[i++] = TransferComponent.unwrapNative.selector;
            selectors[i++] = TransferComponent.unwrapNativeAndTransferTo.selector;
            for (uint256 k; k < 4; ++k) {
                componentAddresses[j++] = contracts.transferComponent;
            }
        }

        if (contracts.multiswapRouterComponent != address(0)) {
            // multiswap Component
            selectors[i++] = MultiswapRouterComponent.wrappedNative.selector;
            selectors[i++] = MultiswapRouterComponent.feeContract.selector;
            selectors[i++] = MultiswapRouterComponent.setFeeContract.selector;
            selectors[i++] = MultiswapRouterComponent.multiswap.selector;
            selectors[i++] = MultiswapRouterComponent.partswap.selector;
            for (uint256 k; k < 5; ++k) {
                componentAddresses[j++] = contracts.multiswapRouterComponent;
            }
        }

        if (contracts.stargateComponent != address(0)) {
            selectors[i++] = StargateComponent.lzEndpoint.selector;
            selectors[i++] = StargateComponent.quoteV2.selector;
            selectors[i++] = StargateComponent.sendStargateV2.selector;
            selectors[i++] = StargateComponent.lzCompose.selector;
            for (uint256 k; k < 4; ++k) {
                componentAddresses[j++] = contracts.stargateComponent;
            }
        }
        // TODO remove duplicates
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
            for (uint256 k; k < 18; ++k) {
                componentAddresses[j++] = contracts.layerZeroComponent;
            }
        }

        assembly {
            mstore(selectors, i)
            mstore(componentAddresses, j)
        }

        return address(
            new Factory({
                componentsAndSelectors: getBytesArray({ selectors: selectors, componentAddresses: componentAddresses })
            })
        );
    }

    function deployImplemetations(
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

            contracts.transferComponent = address(new TransferComponent({ wrappedNative: contracts.wrappedNative }));
        }

        if (contracts.stargateComponent == address(0) || isTest) {
            upgrade = true;

            contracts.stargateComponent = address(new StargateComponent({ endpointV2: contracts.endpointV2 }));
        }

        if (contracts.layerZeroComponent == address(0) || isTest) {
            upgrade = true;

            contracts.layerZeroComponent = address(new LayerZeroComponent({ endpointV2: contracts.endpointV2 }));
        }

        return (contracts, upgrade);
    }

    function getBytesArray(
        bytes4[] memory selectors,
        address[] memory componentAddresses
    )
        internal
        pure
        returns (bytes memory logicsAndSelectors)
    {
        quickSort(selectors, componentAddresses);

        uint256 selectorsLength = selectors.length;
        if (selectorsLength != componentAddresses.length) {
            revert("length of selectors and componentAddresses must be equal");
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

        unchecked {
            logicsAndSelectors = new bytes(selectorsLength * 24);
        }

        assembly ("memory-safe") {
            let logicAndSelectorValue
            // counter
            let i
            // offset in memory to the beginning of selectors array values
            let selectorsOffset := add(selectors, 32)
            // offset in memory to beginning of logicsAddresses array values
            let logicsAddressesOffset := add(componentAddresses, 32)
            // offset in memory to beginning of logicsAndSelectorsOffset bytes
            let logicsAndSelectorsOffset := add(logicsAndSelectors, 32)

            for { } lt(i, selectorsLength) {
                // post actions
                i := add(i, 1)
                selectorsOffset := add(selectorsOffset, 32)
                logicsAddressesOffset := add(logicsAddressesOffset, 32)
                logicsAndSelectorsOffset := add(logicsAndSelectorsOffset, 24)
            } {
                // value creation:
                // 0xaaaaaaaaffffffffffffffffffffffffffffffffffffffff0000000000000000
                logicAndSelectorValue := or(mload(selectorsOffset), shl(64, mload(logicsAddressesOffset)))
                // store the value in the logicsAndSelectors byte array
                mstore(logicsAndSelectorsOffset, logicAndSelectorValue)
            }
        }
    }

    function quickSort(bytes4[] memory selectors, address[] memory componentAddresses) internal pure {
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

            int256 pivotIndex = _partition(selectors, componentAddresses, low, high);

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
        address[] memory componentAddresses,
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

                if (componentAddresses.length == selectors.length) {
                    (componentAddresses[uint256(i)], componentAddresses[uint256(j)]) =
                        (componentAddresses[uint256(j)], componentAddresses[uint256(i)]);
                }
            }
        }

        (selectors[uint256(i + 1)], selectors[uint256(high)]) = (selectors[uint256(high)], selectors[uint256(i + 1)]);

        if (componentAddresses.length == selectors.length) {
            (componentAddresses[uint256(i + 1)], componentAddresses[uint256(high)]) =
                (componentAddresses[uint256(high)], componentAddresses[uint256(i + 1)]);
        }

        return i + 1;
    }
}
