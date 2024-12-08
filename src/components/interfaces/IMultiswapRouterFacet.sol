// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IMultiswapRouterComponent - Multiswap Router Component interface
/// @dev Multiswap Router interface
interface IMultiswapRouterComponent {
    // =========================
    // errors
    // =========================

    /// @notice Throws if `fee` is invalid
    error MultiswapRouterComponent_InvalidFeeValue();

    /// @notice Throws if `sender` is not the owner
    error MultiswapRouterComponent_SenderIsNotOwner();

    /// @notice Throws if amount out is less than minimum amount out
    error MultiswapRouterComponent_InvalidAmountOut();

    /// @notice Throws if swap through UniswapV2 fails
    error MultiswapRouterComponent_FailedV2Swap();

    /// @notice Throws if `pairs` array is empty
    error MultiswapRouterComponent_InvalidPairsArray();

    /// @notice Throws if `multiswap2Calldata` is invalid
    error MultiswapRouterComponent_InvalidMultiswap2Calldata();

    /// @notice Throws if swap through UniswapV3 fails
    error MultiswapRouterComponent_FailedV3Swap();

    /// @notice Throws if `sender` is not a UniswapV3 pool
    error MultiswapRouterComponent_SenderMustBeUniswapV3Pool();

    /// @notice Throws if `amount` is larger than `int256.max`
    error MultiswapRouterComponent_InvalidIntCast();

    /// @notice Throws if `newOwner` is the zero address
    error MultiswapRouterComponent_NewOwnerIsZeroAddress();

    /// @notice Throws if `sender` is not the wrapped native token for receive function
    error MultiswapRouterComponent_InvalidNativeSender();

    /// @notice Throws if `tokenIn` is not in the `pair`
    error MultiswapRouterComponent_InvalidTokenIn();

    /// @notice Throws if `amountIn` is 0
    error MultiswapRouterComponent_InvalidAmountIn();

    // =========================
    // getters
    // =========================

    /// @notice Returns the address of the `wrappedNative`
    function wrappedNative() external view returns (address);

    // =========================
    // main logic
    // =========================

    struct MultiswapCalldata {
        // initial exact value in
        uint256 amountIn;
        // minimal amountOut
        uint256 minAmountOut;
        // first token in swap
        address tokenIn;
        // array of bytes32 values (pairs) involved in the swap
        // from right to left:
        //     address of the pair - 20 bytes
        //     fee in pair - 3 bytes (for V2 pairs)
        //     the highest bit shows which version the pair belongs to
        bytes32[] pairs;
    }

    /// @notice Swaps through the data.pairs array
    function multiswap(MultiswapCalldata calldata data) external returns (uint256);

    struct Multiswap2Calldata {
        // exact value in for part swap
        uint256 fullAmount;
        // minimal amountOut
        uint256 minAmountOut;
        // token in
        address tokenIn;
        // token out
        address tokenOut;
        // array of percentages of fullAmount for each swap, corresponding to the path for the swap from the pairs array
        uint256[] amountInPercentages;
        // array of bytes32[] values (pairs) involved in the swap
        // from left to right:
        //     address of the pair - 20 bytes
        //     fee in pair - 3 bytes (for V2 pairs)
        //     the highest bit shows which version the pair belongs to
        bytes32[][] pairs;
    }

    /// @notice Swaps tokenIn through each path separately
    /// @dev each path in the pairs array must have tokenIn and have the same tokenOut,
    /// the result of swap is the sum after each swap
    function multiswap2(Multiswap2Calldata calldata data) external returns (uint256);
}
