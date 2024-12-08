// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IFactory - Factory interface
interface IFactory {
    // =========================
    // errors
    // =========================

    /// @notice Throws when the function does not exist in the Factory.
    error Factory_FunctionDoesNotExist(bytes4 selector);

    // =========================
    // initializer
    // =========================

    /// @notice Initializes a Factory contract.
    function initialize(address newOwner, bytes[] calldata initialCalls) external;

    /// @notice Executes multiple calls in a single transaction.
    /// @dev Iterates through an array of call data and executes each call.
    /// If any call fails, the function reverts with the original error message.
    /// @param data An array of call data to be executed.
    function multicall(bytes[] calldata data) external payable;

    /// @notice Executes multiple calls in a single transaction.
    /// @dev Iterates through an array of call data and executes each call.
    /// If any call fails, the function reverts with the original error message.
    /// @param replace The offsets to replace.
    /// @dev The offsets are encoded as uint16 in bytes32.
    ///     If the first 16-bit bit after a call is non-zero,
    ///     the result of the call replaces the calldata for the next call at that offset.
    /// @param data An array of call data to be executed.
    function multicall(bytes32 replace, bytes[] calldata data) external payable;

    // =========================
    // admin methods
    // =========================

    /// @notice Sets the address of the fee contract.
    function setFeeContractAddress(address feeContractAddress) external;

    /// @notice Returns the address of the fee contract
    function getFeeContractAddress() external view returns (address feeContractAddress);

    // =========================
    // diamond getters
    // =========================

    // These functions are expected to be called frequently by tools

    struct Component {
        address component;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all component addresses and their four byte function selectors.
    /// @return _components Component
    function components() external view returns (Component[] memory _components);

    /// @notice Gets all the function selectors supported by a specific component.
    /// @param component The component address.
    /// @return _componentFunctionSelectors
    function componentFunctionSelectors(address component) external view returns (bytes4[] memory _componentFunctionSelectors);

    /// @notice Get all the component addresses used by a diamond.
    /// @return _components
    function componentAddresses() external view returns (address[] memory _components);

    /// @notice Gets the component that supports the given selector.
    /// @dev If component is not found return address(0).
    /// @param functionSelector The function selector.
    /// @return _component The component address.
    function componentAddress(bytes4 functionSelector) external view returns (address _component);
}
