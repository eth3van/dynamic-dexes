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
}
