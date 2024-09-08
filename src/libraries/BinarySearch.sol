// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title BinarySearch
/// @dev A library for performing binary search on a bytes array to retrieve addresses.
library BinarySearch {
    /// @notice Searches for the `component` address associated with the given function `selector`.
    /// @dev Uses a binary search algorithm to search within a concatenated bytes array
    /// of component addresses and function selectors. The array is assumed to be sorted
    /// by `selectors`. If the function `selector` exists, the associated `component` address is returned.
    /// @param selector The function selector (4 bytes) to search for.
    /// @param componentsAndSelectors The concatenated bytes array of component addresses and function selectors.
    /// @param length The length of the `selectors` in the `componentsAndSelectors` array.
    /// @param addressesOffset The offset of the `componentAddresses` in the `componentsAndSelectors` array.
    /// @return component The component address associated with the given function selector, or address(0) if not found.
    function binarySearch(
        bytes4 selector,
        bytes memory componentsAndSelectors,
        uint256 length,
        uint256 addressesOffset
    )
        internal
        pure
        returns (address component)
    {
        bytes4 bytes4Mask = bytes4(0xffffffff);

        // binary search
        assembly ("memory-safe") {
            // while(low < high)
            for {
                let offset := add(componentsAndSelectors, 36) // 32 for length + 4 for metadata
                let low
                let high := length
                let mid
                let midValue
                let midSelector
            } lt(low, high) { } {
                mid := shr(1, add(low, high))
                midValue := mload(add(offset, mul(mid, 5)))
                midSelector := and(midValue, bytes4Mask)

                if eq(midSelector, selector) {
                    component := and(shr(216, midValue), 0xff)
                    component := shr(96, mload(add(add(addressesOffset, offset), mul(component, 20))))
                    break
                }

                switch lt(midSelector, selector)
                case 1 { low := add(mid, 1) }
                default { high := mid }
            }
        }
    }
}
