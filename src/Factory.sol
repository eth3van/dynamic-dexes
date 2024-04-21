// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Initializable } from "./proxy/Initializable.sol";
import { UUPSUpgradeable } from "./proxy/UUPSUpgradeable.sol";

import { SSTORE2 } from "./libraries/SSTORE2.sol";
import { BinarySearch } from "./libraries/BinarySearch.sol";

import { IFactory } from "./interfaces/IFactory.sol";
import { Ownable2Step } from "./external/Ownable2Step.sol";

import { CallbackComponentLibrary } from "./libraries/CallbackComponentLibrary.sol";

/// @title Factory
/// @notice This contract serves as a proxy for dynamic function execution.
/// @dev It maps function selectors to their corresponding component contracts.
contract Factory is UUPSUpgradeable, Ownable2Step, Initializable, IFactory {
    //-----------------------------------------------------------------------//
    // function selectors and component addresses are stored as bytes data:      //
    // selector . address                                                    //
    // sample:                                                               //
    // 0xaaaaaaaa <- selector                                                //
    // 0xffffffffffffffffffffffffffffffffffffffff <- address                 //
    // 0xaaaaaaaaffffffffffffffffffffffffffffffffffffffff <- one element     //
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

    /// @notice Initializes a Factory contract.
    function initialize(address newOwner, bytes[] calldata initialCalls) external initializer {
        _transferOwnership(newOwner);

        if (initialCalls.length > 0) {
            _multicall(true, bytes32(0), initialCalls);
        }
    }

    // =========================
    // fallback function
    // =========================

    /// @inheritdoc IFactory
    function multicall(bytes[] calldata data) external payable {
        _multicall(false, bytes32(0), data);
    }

    function multicall(bytes32 insert, bytes[] calldata data) external {
        _multicall(true, insert, data);
    }

    /// @notice Fallback function to execute component associated with incoming function selectors.
    /// @dev If a component for the incoming selector is found, it delegates the call to that component.
    /// @dev If callback address in storage is not address(0) - it delegates the call to that address.
    fallback() external payable {
        address component = CallbackComponentLibrary.getCallbackAddress();

        if (component == address(0)) {
            component = _getAddress(msg.sig);

            if (component == address(0)) {
                revert Factory_FunctionDoesNotExist(msg.sig);
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
    // internal function
    // =======================

    function _multicall(bool isOverride, bytes32 insert, bytes[] calldata data) internal {
        address[] memory components = _getAddresses(isOverride, data);

        assembly ("memory-safe") {
            for {
                let length := data.length
                let memoryOffset := add(components, 32)
                let ptr := mload(64)

                let cDataStart := mul(isOverride, 32)
                let cDataOffset := add(68, cDataStart)
                cDataStart := add(68, cDataStart)

                let component

                let argInsert
            } length {
                length := sub(length, 1)
                cDataOffset := add(cDataOffset, 32)
                memoryOffset := add(memoryOffset, 32)
            } {
                component := mload(memoryOffset)
                let offset := add(cDataStart, calldataload(cDataOffset))
                if iszero(component) {
                    // revert Factory_FunctionDoesNotExist(selector);
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

                if argInsert { if returndatasize() { returndatacopy(add(ptr, argInsert), 0, returndatasize()) } }

                if iszero(delegatecall(gas(), component, ptr, cSize, 0, 0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                if insert {
                    argInsert := and(insert, 0xffff)
                    insert := shr(insert, 16)
                }
            }
        }
    }

    /// @dev Searches for the component address associated with a function `selector`.
    /// @dev Uses binary search to find the component address in componentsAndSelectors bytes.
    /// @param selector The function selector.
    /// @return component The address of the component contract.
    function _getAddress(bytes4 selector) internal view returns (address component) {
        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);

        if (componentsAndSelectors.length < 24) {
            revert Factory_FunctionDoesNotExist(selector);
        }

        return BinarySearch.binarySearch({ selector: selector, componentsAndSelectors: componentsAndSelectors });
    }

    /// @dev Searches for the component addresses associated with a function `selectors`.
    /// @dev Uses binary search to find the component addresses in componentsAndSelectors bytes.
    /// @param datas The calldata to be searched.
    /// @return components The addresses of the component contracts.
    function _getAddresses(bool isOverride, bytes[] calldata datas) internal view returns (address[] memory components) {
        uint256 length = datas.length;
        components = new address[](length);

        bytes memory componentsAndSelectors = SSTORE2.read(_componentsAndSelectorsAddress);

        if (componentsAndSelectors.length < 24) {
            revert Factory_FunctionDoesNotExist(0x00000000);
        }

        uint256 cDataStart;
        uint256 offset;
        assembly ("memory-safe") {
            cDataStart := mul(isOverride, 32)
            offset := add(68, cDataStart)
            cDataStart := add(68, cDataStart)
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

            components[i] = BinarySearch.binarySearch({ selector: selector, componentsAndSelectors: componentsAndSelectors });

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

    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
    /// {upgradeTo} and {upgradeToAndCall}.
    ///
    /// Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
    ///
    /// ```solidity
    /// function _authorizeUpgrade(address) internal override onlyOwner {}
    /// ```
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
