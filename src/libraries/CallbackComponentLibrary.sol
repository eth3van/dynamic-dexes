// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CallbackComponentLibrary
/// @dev library for store callback address
library CallbackComponentLibrary {
    // keccak("callback.component.storage")
    bytes32 internal constant CALLBACK_COMPONENT_STORAGE =
        0x1248b983d56fa782b7a88ee11066fc0746058888ea550df970b9eea952d65dd1;

    /// @notice get callback address
    /// @dev if callback address is not address(0) -> set callback address to address(0)
    function getCallbackAddress() internal returns (address callbackAddress) {
        assembly ("memory-safe") {
            callbackAddress := sload(CALLBACK_COMPONENT_STORAGE)

            if callbackAddress { sstore(CALLBACK_COMPONENT_STORAGE, 0) }
        }
    }

    /// @notice set callback address
    function setCallbackAddress(address callbackAddress) internal {
        assembly ("memory-safe") {
            sstore(CALLBACK_COMPONENT_STORAGE, callbackAddress)
        }
    }
}
