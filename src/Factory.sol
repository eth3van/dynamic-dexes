// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Initializable } from "./proxy/Initializable.sol";
import { UUPSUpgradeable } from "./proxy/UUPSUpgradeable.sol";

import { SSTORE2 } from "./libraries/SSTORE2.sol";
import { BinarySearch } from "./libraries/BinarySearch.sol";

import { IFactory } from "./interfaces/IFactory.sol";
import { Ownable2Step } from "./external/Ownable2Step.sol";

import { TransientStorageComponentLibrary } from "./libraries/TransientStorageComponentLibrary.sol";
import { FeeLibrary } from "./libraries/FeeLibrary.sol";

/// @title Factory
/// @notice This contract serves as a proxy for dynamic function execution.
/// @dev It maps function selectors to their corresponding component contracts.
contract Factory is Ownable2Step, UUPSUpgradeable, Initializable, IFactory {
    //-----------------------------------------------------------------------//
    // function selectors and address indexes are stored as bytes data:      //
    // selector . addressIndex                                               //
    // sample:                                                               //
    // 0xaaaaaaaa <- selector                                                //
    // 0xff <- addressIndex                                                  //
    // 0xaaaaaaaaff <- one element                                           //
    //                                                                       //
    // componentAddresses are stored in the end of the bytes array              //
    //-----------------------------------------------------------------------//

    /// @dev Address where component and selector bytes are stored using SSTORE2.
    address private immutable _componentsAndSelectorsAddress;

    // =========================
    // constructor
    // =========================

    /// @notice Initializes a Factory contract.
    /// @param componentsAndSelectors A bytes array of bytes4 function selectors and component addresses.
    ///
    /// @dev Sets up the component and selectors for the Factory contract,
    /// ensuring that the passed selectors are in order and there are no repetitions.
    /// @dev Ensures that the sizes of selectors and component addresses match.
    /// @dev The constructor uses SSTORE2 method to stores the combined component and selectors
    /// in a specified storage location.
    constructor(bytes memory componentsAndSelectors) {
        _disableInitializers();

        _componentsAndSelectorsAddress = SSTORE2.write({ data: componentsAndSelectors });
    }

    /// @inheritdoc IFactory
    function initialize(address newOwner, bytes[] calldata initialCalls) external initializer {
        _transferOwnership(newOwner);

        if (initialCalls.length > 0) {
            _multicall(true, bytes32(0), initialCalls);
        }
    }

    // =========================
    // admin methods
    // =========================

    /// @inheritdoc IFactory
    function setFeeContractAddress(address feeContractAddress) external onlyOwner {
        FeeLibrary.setFeeContractAddress(feeContractAddress);
    }

    /// @inheritdoc IFactory
    function getFeeContractAddress() external view returns (address feeContractAddress) {
        feeContractAddress = FeeLibrary.getFeeContractAddress();
    }

    // =========================
    // fallback functions
    // =========================

    /// @inheritdoc IFactory
    function multicall(bytes[] calldata data) external payable {
        _multicall(false, bytes32(0), data);
    }

    /// @inheritdoc IFactory
    function multicall(bytes32 replace, bytes[] calldata data) external payable {
        _multicall(true, replace, data);
    }

    /// @notice Fallback function to execute component associated with incoming function selectors.
    /// @dev If a component for the incoming selector is found, it delegates the call to that component.
    /// @dev If callback address in storage is not address(0) - it delegates the call to that address.
    fallback() external payable {
        address component = TransientStorageComponentLibrary.getCallbackAddress();

        if (component == address(0)) {
            component = _getAddress(msg.sig);

            if (component == address(0)) {
                revert IFactory.Factory_FunctionDoesNotExist({ selector: msg.sig });
            }
        }

        assembly ("memory-safe") {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), component, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @notice Function to receive Native currency.
    receive() external payable { }

    // =======================
    // diamond getters
    // =======================

    /// @inheritdoc IFactory
    function components() external view returns (IFactory.Component[] memory _components) {
        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);
        address[] memory _componentsRaw = _getAddresses(componentsAndSelectors);

        _components = new IFactory.Component[](_componentsRaw.length);

        for (uint256 i; i < _componentsRaw.length;) {
            _components[i].component = _componentsRaw[i];
            _components[i].functionSelectors = _getComponentFunctionSelectors(componentsAndSelectors, i);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IFactory
    function componentFunctionSelectors(address component) external view returns (bytes4[] memory _componentFunctionSelectors) {
        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);
        address[] memory _components = _getAddresses(componentsAndSelectors);

        uint256 componentIndex = type(uint64).max;
        for (uint256 i; i < _components.length;) {
            if (_components[i] == component) {
                componentIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        _componentFunctionSelectors = _getComponentFunctionSelectors(componentsAndSelectors, componentIndex);
    }

    /// @inheritdoc IFactory
    function componentAddresses() external view returns (address[] memory _components) {
        _components = _getAddresses(SSTORE2.read(_componentsAndSelectorsAddress));
    }

    /// @inheritdoc IFactory
    function componentAddress(bytes4 functionSelector) external view returns (address _component) {
        _component = _getAddress(functionSelector);
    }

    // =======================
    // internal function
    // =======================

    function _multicall(bool isOverride, bytes32 replace, bytes[] calldata data) internal {
        address[] memory _components = _getAddresses(isOverride, data);

        TransientStorageComponentLibrary.setSenderAddress({ senderAddress: msg.sender });

        assembly ("memory-safe") {
            for {
                let length := data.length
                let memoryOffset := add(_components, 32)
                let ptr := mload(64)

                let cDataStart := mul(isOverride, 32)
                let cDataOffset := add(68, cDataStart)
                cDataStart := add(68, cDataStart)

                let component

                let argReplace
            } length {
                length := sub(length, 1)
                cDataOffset := add(cDataOffset, 32)
                memoryOffset := add(memoryOffset, 32)
            } {
                component := mload(memoryOffset)
                let offset := add(cDataStart, calldataload(cDataOffset))
                if iszero(component) {
                    // revert IFactory.Factory_FunctionDoesNotExist(selector);
                    mstore(0, 0x9365f537)
                    mstore(
                        32,
                        and(
                            calldataload(add(offset, 32)),
                            0xffffffff00000000000000000000000000000000000000000000000000000000
                        )
                    )
                    revert(28, 36)
                }

                let cSize := calldataload(offset)
                calldatacopy(ptr, add(offset, 32), cSize)

                // all methods will return only 32 bytes
                if argReplace {
                    if returndatasize() { returndatacopy(add(ptr, argReplace), 0, 32) }
                    argReplace := 0
                }

                if iszero(callcode(gas(), component, 0, ptr, cSize, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                if replace {
                    argReplace := and(replace, 0xffff)
                    replace := shr(16, replace)
                }
            }
        }

        TransientStorageComponentLibrary.setSenderAddress({ senderAddress: address(0) });
    }

    /// @dev Searches for the component address associated with a function `selector`.
    /// @dev Uses binary search to find the component address in componentsAndSelectors bytes.
    /// @param selector The function selector.
    /// @return component The address of the component contract.
    function _getAddress(bytes4 selector) internal view returns (address component) {
        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);

        if (componentsAndSelectors.length < 24) {
            revert IFactory.Factory_FunctionDoesNotExist({ selector: selector });
        }

        uint256 selectorsLength;
        uint256 addressesOffset;
        assembly ("memory-safe") {
            let value := shr(224, mload(add(32, componentsAndSelectors)))
            selectorsLength := shr(16, value)
            addressesOffset := and(value, 0xffff)
        }

        return BinarySearch.binarySearch({
            selector: selector,
            componentsAndSelectors: componentsAndSelectors,
            length: selectorsLength,
            addressesOffset: addressesOffset
        });
    }

    /// @dev Searches for the component addresses associated with a function `selectors`.
    /// @dev Uses binary search to find the component addresses in componentsAndSelectors bytes.
    /// @param datas The calldata to be searched.
    /// @return _components The addresses of the component contracts.
    function _getAddresses(bool isOverride, bytes[] calldata datas) internal view returns (address[] memory _components) {
        uint256 length = datas.length;
        _components = new address[](length);

        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);

        if (componentsAndSelectors.length < 24) {
            revert IFactory.Factory_FunctionDoesNotExist({ selector: 0x00000000 });
        }

        uint256 cDataStart;
        uint256 offset;
        uint256 selectorsLength;
        uint256 addressesOffset;
        assembly ("memory-safe") {
            cDataStart := mul(isOverride, 32)
            offset := add(68, cDataStart)
            cDataStart := add(68, cDataStart)

            let value := shr(224, mload(add(32, componentsAndSelectors)))
            selectorsLength := shr(16, value)
            addressesOffset := and(value, 0xffff)
        }

        bytes4 selector;
        for (uint256 i; i < length;) {
            assembly ("memory-safe") {
                selector :=
                    and(
                        calldataload(add(cDataStart, add(calldataload(offset), 32))),
                        0xffffffff00000000000000000000000000000000000000000000000000000000
                    )
                offset := add(offset, 32)
            }

            _components[i] = BinarySearch.binarySearch({
                selector: selector,
                componentsAndSelectors: componentsAndSelectors,
                length: selectorsLength,
                addressesOffset: addressesOffset
            });

            unchecked {
                // increment loop counter
                ++i;
            }
        }

        assembly ("memory-safe") {
            // re-use unnecessary memory
            mstore(64, componentsAndSelectors)
        }
    }

    /// @dev Returns the addresses of the components.
    function _getAddresses(bytes memory componentsAndSelectors) internal pure returns (address[] memory _components) {
        assembly ("memory-safe") {
            let counter
            for {
                _components := mload(64)
                let addressesOffset :=
                    add(
                        add(componentsAndSelectors, 36), // 32 for length + 4 for metadata
                        and(shr(224, mload(add(32, componentsAndSelectors))), 0xffff)
                    )
                let offset := add(_components, 32)
            } 1 {
                offset := add(offset, 32)
                addressesOffset := add(addressesOffset, 20)
            } {
                let value := shr(96, mload(addressesOffset))
                if iszero(value) { break }
                mstore(offset, value)
                counter := add(counter, 1)
            }

            mstore(_components, counter)
            mstore(64, add(mload(64), add(32, mul(counter, 32))))
        }
    }

    /// @dev Returns the selectors of the component with the given index.
    function _getComponentFunctionSelectors(
        bytes memory componentsAndSelectors,
        uint256 componentIndex
    )
        internal
        pure
        returns (bytes4[] memory _componentFunctionSelectors)
    {
        assembly ("memory-safe") {
            let counter
            for {
                _componentFunctionSelectors := mload(64)
                let offset := add(_componentFunctionSelectors, 32)
                let selectorsOffset := add(componentsAndSelectors, 36) // 32 for length + 4 for metadata
                let selectorsLength := shr(240, mload(add(32, componentsAndSelectors)))
            } selectorsLength {
                selectorsLength := sub(selectorsLength, 1)
                selectorsOffset := add(selectorsOffset, 5)
            } {
                let selector := mload(selectorsOffset)
                if eq(and(shr(216, selector), 0xff), componentIndex) {
                    mstore(offset, and(selector, 0xffffffff00000000000000000000000000000000000000000000000000000000))
                    counter := add(counter, 1)
                    offset := add(offset, 32)
                }
            }

            mstore(_componentFunctionSelectors, counter)
            mstore(64, add(mload(64), add(32, mul(counter, 32))))
        }
    }

    /// @dev Function that should revert IFactory.when `msg.sender` is not authorized to upgrade the contract. Called by
    /// {upgradeTo} and {upgradeToAndCall}.
    ///
    /// Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
    ///
    /// ```solidity
    /// function _authorizeUpgrade(address) internal override onlyOwner {}
    /// ```
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
