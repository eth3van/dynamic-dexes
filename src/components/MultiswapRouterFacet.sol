// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { BaseOwnableComponent } from "./BaseOwnableComponent.sol";

import { IRouter } from "./interfaces/IRouter.sol";
import { HelperLib } from "./libraries/HelperLib.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";

import { IMultiswapRouterComponent } from "./interfaces/IMultiswapRouterComponent.sol";
import { IWrappedNative } from "./interfaces/IWrappedNative.sol";

import { CallbackComponentLibrary } from "../libraries/CallbackComponentLibrary.sol";

import { IFeeContract } from "../interfaces/IFeeContract.sol";

/// @title Multiswap Router Component
/// @notice Router for UniswapV3 and UniswapV2 multiswaps and partswaps
contract MultiswapRouterComponent is BaseOwnableComponent, IMultiswapRouterComponent {
    // =========================
    // storage
    // =========================

    /// @dev address of the WrappedNative contract for current chain
    IWrappedNative private immutable _wrappedNative;

    address private immutable _self;

    /// @dev mask for UniswapV3 pair designation
    /// if `mask & pair == true`, the swap is performed using the UniswapV3 logic
    bytes32 private constant UNISWAP_V3_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    /// address mask: `mask & pair == address(pair)`
    address private constant ADDRESS_MASK = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    /// fee mask: `mask & (pair >> 160) == fee in pair`
    uint24 private constant FEE_MASK = 0xffffff;

    /// @dev minimum and maximum possible values of SQRT_RATIO in UniswapV3
    uint160 private constant MIN_SQRT_RATIO_PLUS_ONE = 4_295_128_740;
    uint160 private constant MAX_SQRT_RATIO_MINUS_ONE =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

    /// @dev 2**255 - 1
    uint256 private constant CAST_INT_CONSTANT =
        57_896_044_618_658_097_711_785_492_504_343_953_926_634_992_332_820_282_019_728_792_003_956_564_819_967;

    struct MultiswapRouterComponentStorage {
        /// @dev cache for swapV3Callback
        address poolAddressCache;
        IFeeContract feeContract;
    }

    /// @dev Storage position for the multiswap router component, to avoid collisions in storage.
    /// @dev Uses the "magic" constant to find a unique storage slot.
    bytes32 private immutable MULTISWAP_ROUTER_COMPONENT_STORAGE = keccak256("multiswap.router.storage");

    /// @dev Returns the storage slot for the entry point logic.
    /// @dev This function utilizes inline assembly to directly access the desired storage position.
    ///
    /// @return s The storage slot pointer for the entry point logic.
    function _getLocalStorage() internal view returns (MultiswapRouterComponentStorage storage s) {
        bytes32 position = MULTISWAP_ROUTER_COMPONENT_STORAGE;
        assembly ("memory-safe") {
            s.slot := position
        }
    }

    // =========================
    // constructor
    // =========================

    constructor(address wrappedNative_) {
        _wrappedNative = IWrappedNative(wrappedNative_);

        _self = address(this);
    }

    // =========================
    // getters
    // =========================

    /// @inheritdoc IMultiswapRouterComponent
    function wrappedNative() external view returns (address) {
        return address(_wrappedNative);
    }

    /// @inheritdoc IMultiswapRouterComponent
    function feeContract() external view returns (address) {
        return address(_getLocalStorage().feeContract);
    }

    // =========================
    // admin logic
    // =========================

    /// @inheritdoc IMultiswapRouterComponent
    function setFeeContract(address newFeeContract) external onlyOwner {
        _getLocalStorage().feeContract = IFeeContract(newFeeContract);
    }

    // =========================
    // main logic
    // =========================

    //// @inheritdoc IMultiswapRouterComponent
    function multiswap(MultiswapCalldata calldata data, address to) external payable returns (uint256 amount) {
        bool isNative = _wrapNative(data.tokenIn, data.amountIn);

        address tokenOut;
        (tokenOut, amount, isNative) = _multiswap(isNative, data);

        if (to > address(0)) {
            _sendTokens(isNative, tokenOut, amount, data.unwrap, to);
        }
    }

    //// @inheritdoc IMultiswapRouterComponent
    function partswap(PartswapCalldata calldata data, address to) external payable returns (uint256 amount) {
        address tokenIn = data.tokenIn;
        uint256 fullAmount = data.fullAmount;
        bool isNative = _wrapNative(tokenIn, fullAmount);

        (amount, isNative) = _partswap(isNative, fullAmount, isNative ? address(_wrappedNative) : tokenIn, data);

        if (to > address(0)) {
            _sendTokens(isNative, data.tokenOut, amount, data.unwrap, to);
        }
    }

    // for V3Callback
    fallback() external {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        // Checking that msg.sender is equal to the value from the cache
        // and zeroing the storage
        if (msg.sender != s.poolAddressCache) {
            revert MultiswapRouterComponent_SenderMustBeUniswapV3Pool();
        }
        s.poolAddressCache = address(0);

        int256 amount0Delta;
        int256 amount1Delta;
        address tokenIn;

        assembly ("memory-safe") {
            amount0Delta := calldataload(4)
            amount1Delta := calldataload(36)
            tokenIn := calldataload(132)
        }

        // swaps entirely within 0-liquidity regions are not supported
        if (amount0Delta == 0 && amount1Delta == 0) {
            revert MultiswapRouterComponent_FailedV3Swap();
        }

        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);

        // transfer tokens to the pool address
        TransferHelper.safeTransfer({ token: tokenIn, to: msg.sender, value: amountToPay });
    }

    // =========================
    // internal methods
    // =========================

    /// @dev Swaps through the data.pairs array
    function _multiswap(bool isNative, MultiswapCalldata calldata data) internal returns (address, uint256, bool) {
        // cache length of pairs to stack for gas savings
        uint256 length = data.pairs.length;
        // if length of array is zero -> revert
        if (length == 0) {
            revert MultiswapRouterComponent_InvalidArray();
        }

        uint256 lastIndex;
        unchecked {
            lastIndex = length - 1;
        }

        bytes32 pair = data.pairs[0];
        bool uni3;

        address tokenIn;
        uint256 amountIn = data.amountIn;

        // scope for transfer, avoids stack too deep errors
        {
            address firstPair;

            assembly ("memory-safe") {
                // take the first pair in the array
                firstPair := and(pair, ADDRESS_MASK)
                // find out which version of the protocol it belongs to
                uni3 := and(pair, UNISWAP_V3_MASK)
            }

            if (isNative) {
                tokenIn = address(_wrappedNative);

                // execute transfer:
                //     if the pair belongs to version 2 of the protocol -> transfer tokens to the pair
                if (!uni3) {
                    TransferHelper.safeTransfer({ token: tokenIn, to: firstPair, value: amountIn });
                }
            } else {
                tokenIn = data.tokenIn;

                if (TransferHelper.safeGetBalance({ token: tokenIn, account: address(this) }) < amountIn) {
                    // execute transferFrom:
                    //     if the pair belongs to version 2 of the protocol -> transfer tokens to the pair
                    //     if version 3 - to this contract
                    TransferHelper.safeTransferFrom({
                        token: tokenIn,
                        from: msg.sender,
                        to: uni3 ? address(this) : firstPair,
                        value: amountIn
                    });
                }
            }
        }

        uint256 balanceOutBeforeLastSwap;

        // scope for swaps, avoids stack too deep errors
        {
            bytes32 addressThisBytes32 = _addressThisBytes32();
            bool uni3Next;
            bytes32 destination;
            for (uint256 i; i < length; i = _unsafeAddOne(i)) {
                if (i == lastIndex) {
                    // if the pair is the last in the array - the next token recipient after the swap is address(this)
                    destination = addressThisBytes32;
                } else {
                    // otherwise take the next pair
                    destination = data.pairs[_unsafeAddOne(i)];
                }

                assembly ("memory-safe") {
                    // if the next pair belongs to version 3 of the protocol - the address
                    // of the router is set as the recipient, otherwise - the next pair
                    uni3Next := and(destination, UNISWAP_V3_MASK)
                }

                if (uni3) {
                    (amountIn, tokenIn, balanceOutBeforeLastSwap) =
                        _swapUniV3(i == lastIndex, pair, amountIn, tokenIn, uni3Next ? addressThisBytes32 : destination);
                } else {
                    (amountIn, tokenIn, balanceOutBeforeLastSwap) =
                        _swapUniV2(i == lastIndex, pair, tokenIn, uni3Next ? addressThisBytes32 : destination);
                }
                // upgrade the pair for the next swap
                pair = destination;
                uni3 = uni3Next;
            }
        }

        uint256 balanceOutAfterLastSwap = TransferHelper.safeGetBalance({ token: tokenIn, account: address(this) });

        if (balanceOutAfterLastSwap < balanceOutBeforeLastSwap) {
            revert MultiswapRouterComponent_InvalidOutAmount();
        }

        uint256 exactAmountOut;
        unchecked {
            exactAmountOut = balanceOutAfterLastSwap - balanceOutBeforeLastSwap;
        }

        if (exactAmountOut < data.minAmountOut) {
            revert MultiswapRouterComponent_InvalidOutAmount();
        }

        {
            IFeeContract _feeContract = _getLocalStorage().feeContract;
            if (address(_feeContract) != address(0)) {
                TransferHelper.safeApprove({ token: tokenIn, spender: address(_feeContract), value: exactAmountOut });
                exactAmountOut = _feeContract.writeFees(data.referralAddress, tokenIn, exactAmountOut);
            }
        }

        return (tokenIn, exactAmountOut, tokenIn == address(_wrappedNative));
    }

    /// @dev Swaps tokenIn through each pair separately
    function _partswap(
        bool isNative,
        uint256 fullAmount,
        address tokenIn,
        PartswapCalldata calldata data
    )
        internal
        returns (uint256, bool)
    {
        // cache length of pairs to stack for gas savings
        uint256 length = data.pairs.length;
        // if length of array is zero -> revert
        if (length == 0) {
            revert MultiswapRouterComponent_InvalidArray();
        }
        if (length != data.amountsIn.length) {
            revert MultiswapRouterComponent_InvalidPartswapCalldata();
        }

        {
            uint256 fullAmountCheck;
            for (uint256 i; i < length; i = _unsafeAddOne(i)) {
                unchecked {
                    fullAmountCheck += data.amountsIn[i];
                }
            }

            // sum of amounts array must be lte to fullAmount
            if (fullAmountCheck > fullAmount) {
                revert MultiswapRouterComponent_InvalidPartswapCalldata();
            }

            if (!isNative) {
                // Transfer full amount in for all swaps
                TransferHelper.safeTransferFrom({
                    token: tokenIn,
                    from: msg.sender,
                    to: address(this),
                    value: fullAmount
                });
            }
        }

        address tokenOut = data.tokenOut;
        bytes32 addressThisBytes32 = _addressThisBytes32();

        bytes32 pair;
        bool uni3;
        uint256 amountBefore = TransferHelper.safeGetBalance({ token: tokenOut, account: address(this) });

        for (uint256 i; i < length; i = _unsafeAddOne(i)) {
            pair = data.pairs[i];
            assembly ("memory-safe") {
                uni3 := and(pair, UNISWAP_V3_MASK)
            }

            if (uni3) {
                _swapUniV3(false, pair, data.amountsIn[i], tokenIn, addressThisBytes32);
            } else {
                address _pair;
                assembly ("memory-safe") {
                    _pair := and(pair, ADDRESS_MASK)
                }
                TransferHelper.safeTransfer({ token: tokenIn, to: _pair, value: data.amountsIn[i] });
                _swapUniV2(false, pair, tokenIn, addressThisBytes32);
            }
        }

        uint256 amountAfter = TransferHelper.safeGetBalance({ token: tokenOut, account: address(this) });

        if (amountAfter < amountBefore) {
            revert MultiswapRouterComponent_InvalidOutAmount();
        }

        uint256 exactAmountOut;
        unchecked {
            exactAmountOut = amountAfter - amountBefore;
        }

        if (exactAmountOut < data.minAmountOut) {
            revert MultiswapRouterComponent_InvalidOutAmount();
        }

        {
            IFeeContract _feeContract = _getLocalStorage().feeContract;
            if (address(_feeContract) != address(0)) {
                TransferHelper.safeApprove({ token: tokenOut, spender: address(_feeContract), value: exactAmountOut });
                exactAmountOut = _feeContract.writeFees(data.referralAddress, tokenOut, exactAmountOut);
            }
        }

        return (exactAmountOut, tokenOut == address(_wrappedNative));
    }

    /// @dev uniswapV3 swap exact tokens
    function _swapUniV3(
        bool lastSwap,
        bytes32 _pool,
        uint256 amountIn,
        address tokenIn,
        bytes32 _destination
    )
        internal
        returns (uint256 amountOut, address tokenOut, uint256 balanceOutBeforeLastSwap)
    {
        IRouter pool;
        address destination;
        assembly ("memory-safe") {
            pool := and(_pool, ADDRESS_MASK)
            destination := and(_destination, ADDRESS_MASK)
        }

        // if token0 in the pool is tokenIn - tokenOut == token1, otherwise tokenOut == token0
        tokenOut = pool.token0();
        if (tokenOut == tokenIn) {
            tokenOut = pool.token1();
        }

        if (lastSwap) {
            balanceOutBeforeLastSwap = TransferHelper.safeGetBalance({ token: tokenOut, account: address(this) });
        }

        bool zeroForOne = tokenIn < tokenOut;

        // cast a uint256 to a int256, revert on overflow
        // https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/SafeCast.sol#L24
        if (amountIn > CAST_INT_CONSTANT) {
            revert MultiswapRouterComponent_InvalidIntCast();
        }

        // caching pool address and callback address in storage
        _getLocalStorage().poolAddressCache = address(pool);
        CallbackComponentLibrary.setCallbackAddress({ callbackAddress: _self });

        (int256 amount0, int256 amount1) = pool.swap({
            recipient: destination,
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountIn),
            sqrtPriceLimitX96: (zeroForOne ? MIN_SQRT_RATIO_PLUS_ONE : MAX_SQRT_RATIO_MINUS_ONE),
            data: abi.encode(tokenIn)
        });

        // return the number of tokens received as a result of the swap
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @dev uniswapV2 swap exact tokens
    function _swapUniV2(
        bool lastSwap,
        bytes32 _pair,
        address tokenIn,
        bytes32 _destination
    )
        internal
        returns (uint256 amountOutput, address tokenOut, uint256 balanceOutBeforeLastSwap)
    {
        IRouter pair;
        uint256 fee;
        address destination;
        assembly ("memory-safe") {
            pair := and(_pair, ADDRESS_MASK)
            fee := and(FEE_MASK, shr(160, _pair))
            destination := and(_destination, ADDRESS_MASK)
        }

        // if token0 in the pool is tokenIn - tokenOut == token1, otherwise tokenOut == token0
        address token0 = pair.token0();
        tokenOut = tokenIn == token0 ? pair.token1() : token0;

        if (lastSwap) {
            balanceOutBeforeLastSwap = TransferHelper.safeGetBalance({ token: tokenOut, account: address(this) });
        }

        uint256 amountInput;
        // scope to avoid stack too deep errors
        {
            (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
            (uint256 reserveInput, uint256 reserveOutput) =
                tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

            // get the exact number of tokens that were sent to the pair
            // underflow is impossible cause after token transfer via token contract
            // reserves in the pair not updated yet
            unchecked {
                amountInput = TransferHelper.safeGetBalance({ token: tokenIn, account: address(pair) }) - reserveInput;
            }

            // get the output number of tokens after swap
            amountOutput = HelperLib.getAmountOut({
                amountIn: amountInput,
                reserveIn: reserveInput,
                reserveOut: reserveOutput,
                feeE6: fee
            });
        }

        (uint256 amount0Out, uint256 amount1Out) =
            tokenIn == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));

        if (
            // first do the swap via the most common swap function selector
            // swap(uint256,uint256,address,bytes) selector
            !_makeCall(address(pair), abi.encodeWithSelector(0x022c0d9f, amount0Out, amount1Out, destination, bytes("")))
        ) {
            if (
                // if revert - try to swap through another selector
                // swap(uint256,uint256,address) selector
                !_makeCall(address(pair), abi.encodeWithSelector(0x6d9a640a, amount0Out, amount1Out, destination))
            ) {
                revert MultiswapRouterComponent_FailedV2Swap();
            }
        }
    }

    /// @dev check for overflow has been removed for optimization
    function _unsafeAddOne(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }

    /// @dev returns address(this) in bytes32 format
    function _addressThisBytes32() internal view returns (bytes32 addressThisBytes32) {
        assembly ("memory-safe") {
            addressThisBytes32 := address()
        }
    }

    /// @dev low-level call, returns true if successful
    function _makeCall(address addr, bytes memory data) internal returns (bool success) {
        (success,) = addr.call(data);
    }

    /// @dev wraps native token if needed
    function _wrapNative(address tokenIn, uint256 amount) internal returns (bool isNative) {
        isNative = tokenIn == address(0);

        if (isNative && msg.value >= amount) {
            _wrappedNative.deposit{ value: amount }();
        }
    }

    /// @dev sends tokens or unwrap and send native
    function _sendTokens(bool isNative, address token, uint256 amount, bool unwrap, address to) internal {
        if (isNative && unwrap) {
            _wrappedNative.withdraw({ wad: amount });
            TransferHelper.safeTransferNative({ to: to, value: amount });
        } else {
            TransferHelper.safeTransfer({ token: token, to: to, value: amount });
        }
    }
}
