// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { BaseOwnableComponent } from "./BaseOwnableComponent.sol";

import { IRouter } from "./interfaces/IRouter.sol";
import { HelperLib } from "./libraries/HelperLib.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";

import { IMultiswapRouterComponent } from "./interfaces/IMultiswapRouterComponent.sol";
import { IWrappedNative } from "./interfaces/IWrappedNative.sol";

/// @title Multiswap Router Component
/// @notice Router for UniswapV3 and UniswapV2 multiswaps and partswaps
contract MultiswapRouterComponent is BaseOwnableComponent, IMultiswapRouterComponent {
    // =========================
    // storage
    // =========================

    /// @dev address of the WrappedNative contract for current chain
    IWrappedNative private immutable _wrappedNative;

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

    /// @dev fee logic
    uint256 private constant FEE_MAX = 10_000;

    uint256 private constant PROTOCOL_PART_MASK = 0xffffffffffffffffffffffffffffffff;

    struct MultiswapRouterComponentStorage {
        uint256 protocolFee;
        /// @dev protocolPart of referralFee: _referralFee & PROTOCOL_PART_MASK
        /// referralPart of referralFee: _referralFee >> 128
        uint256 referralFee;
        mapping(address owner => mapping(address token => uint256 balance)) profit;
        /// @dev cache for swapV3Callback
        address poolAddressCache;
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
    }

    // =========================
    // getters
    // =========================

    /// @inheritdoc IMultiswapRouterComponent
    function wrappedNative() external view returns (address) {
        return address(_wrappedNative);
    }

    /// @inheritdoc IMultiswapRouterComponent
    function profit(address owner, address token) external view returns (uint256 balance) {
        return _getLocalStorage().profit[owner][token];
    }

    /// @inheritdoc IMultiswapRouterComponent
    function fees() external view returns (uint256 protocolFee, ReferralFee memory referralFee) {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        assembly ("memory-safe") {
            protocolFee := sload(s.slot)

            let referralFee_ := sload(add(s.slot, 1))
            mstore(referralFee, and(PROTOCOL_PART_MASK, referralFee_))
            mstore(add(referralFee, 32), shr(128, referralFee_))
        }
    }

    // =========================
    // admin logic
    // =========================

    /// @inheritdoc IMultiswapRouterComponent
    function changeProtocolFee(uint256 newProtocolFee) external onlyOwner {
        if (newProtocolFee > FEE_MAX) {
            revert MultiswapRouterComponent_InvalidFeeValue();
        }
        _getLocalStorage().protocolFee = newProtocolFee;
    }

    /// @inheritdoc IMultiswapRouterComponent
    function changeReferralFee(ReferralFee calldata newReferralFee) external onlyOwner {
        unchecked {
            uint256 protocolPart = newReferralFee.protocolPart;
            uint256 referralPart = newReferralFee.referralPart;

            MultiswapRouterComponentStorage storage s = _getLocalStorage();

            if ((referralPart + protocolPart) > s.protocolFee) {
                revert MultiswapRouterComponent_InvalidFeeValue();
            }

            assembly ("memory-safe") {
                sstore(add(s.slot, 1), or(shl(128, referralPart), protocolPart))
            }
        }
    }

    // =========================
    // fees logic
    // =========================

    /// @inheritdoc IMultiswapRouterComponent
    function collectProtocolFees(address token, address recipient, uint256 amount) external onlyOwner {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        uint256 balanceOf = s.profit[address(this)][token];
        if (balanceOf >= amount) {
            unchecked {
                s.profit[address(this)][token] -= amount;
            }
            TransferHelper.safeTransfer(token, recipient, amount);
        }
    }

    /// @inheritdoc IMultiswapRouterComponent
    function collectReferralFees(address token, address recipient, uint256 amount) external {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        uint256 balanceOf = s.profit[msg.sender][token];
        if (balanceOf >= amount) {
            unchecked {
                s.profit[msg.sender][token] -= amount;
            }
            TransferHelper.safeTransfer(token, recipient, amount);
        }
    }

    /// @inheritdoc IMultiswapRouterComponent
    function collectProtocolFees(address token, address recipient) external onlyOwner {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        uint256 balanceOf = s.profit[address(this)][token];
        if (balanceOf > 0) {
            unchecked {
                s.profit[address(this)][token] = 0;
            }
            TransferHelper.safeTransfer(token, recipient, balanceOf);
        }
    }

    /// @inheritdoc IMultiswapRouterComponent
    function collectReferralFees(address token, address recipient) external {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        uint256 balanceOf = s.profit[msg.sender][token];
        if (balanceOf > 0) {
            unchecked {
                s.profit[msg.sender][token] = 0;
            }
            TransferHelper.safeTransfer(token, recipient, balanceOf);
        }
    }

    // =========================
    // main logic
    // =========================

    //// @inheritdoc IMultiswapRouterComponent
    function multiswap(MultiswapCalldata calldata data, address to) external payable {
        bool isNative = _wrapNative();

        address tokenOut;
        uint256 amount;
        (tokenOut, amount, isNative) = _multiswap(isNative, data);

        _sendTokens(isNative, tokenOut, amount, data.unwrap, to == address(0) ? msg.sender : to);
    }

    //// @inheritdoc IMultiswapRouterComponent
    function partswap(PartswapCalldata calldata data, address to) external payable {
        bool isNative = _wrapNative();

        uint256 amount;

        (amount, isNative) = _partswap(
            isNative, isNative ? msg.value : data.fullAmount, isNative ? address(_wrappedNative) : data.tokenIn, data
        );

        _sendTokens(isNative, data.tokenOut, amount, data.unwrap, to == address(0) ? msg.sender : to);
    }

    // for unwrap native currency
    receive() external payable {
        if (msg.sender != address(_wrappedNative)) {
            revert MultiswapRouterComponent_InvalidNativeSender();
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
        TransferHelper.safeTransfer(tokenIn, msg.sender, amountToPay);
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
        uint256 amountIn;

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
                amountIn = msg.value;

                // execute transfer:
                //     if the pair belongs to version 2 of the protocol -> transfer tokens to the pair
                if (!uni3) {
                    TransferHelper.safeTransfer(tokenIn, firstPair, amountIn);
                }
            } else {
                tokenIn = data.tokenIn;
                amountIn = data.amountIn;

                // execute transferFrom:
                //     if the pair belongs to version 2 of the protocol -> transfer tokens to the pair
                //     if version 3 - to this contract
                TransferHelper.safeTransferFrom(tokenIn, msg.sender, uni3 ? address(this) : firstPair, amountIn);
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

        uint256 balanceOutAfterLastSwap = IERC20(tokenIn).balanceOf(address(this));

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

        exactAmountOut = _writeFees(exactAmountOut, data.referralAddress, tokenIn);

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
                TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), fullAmount);
            }
        }

        address tokenOut = data.tokenOut;
        bytes32 addressThisBytes32 = _addressThisBytes32();

        bytes32 pair;
        bool uni3;
        uint256 amountBefore = IERC20(tokenOut).balanceOf(address(this));

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
                TransferHelper.safeTransfer(tokenIn, _pair, data.amountsIn[i]);
                _swapUniV2(false, pair, tokenIn, addressThisBytes32);
            }
        }

        uint256 amountAfter = IERC20(tokenOut).balanceOf(address(this));

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

        exactAmountOut = _writeFees(exactAmountOut, data.referralAddress, tokenOut);

        return (exactAmountOut, tokenOut == address(_wrappedNative));
    }

    /// @dev Function that writes protocol and referral fees for swaps
    function _writeFees(uint256 exactAmount, address referralAddress, address token) internal returns (uint256) {
        MultiswapRouterComponentStorage storage s = _getLocalStorage();

        if (referralAddress == address(0)) {
            unchecked {
                uint256 fee = (exactAmount * s.protocolFee) / FEE_MAX;
                s.profit[address(this)][token] += fee;

                return exactAmount - fee;
            }
        } else {
            uint256 protocolPart;
            uint256 referralPart;
            assembly ("memory-safe") {
                let referralFee_ := sload(add(s.slot, 1))
                protocolPart := and(PROTOCOL_PART_MASK, referralFee_)
                referralPart := shr(128, referralFee_)
            }

            unchecked {
                uint256 referralFeePart = (exactAmount * referralPart) / FEE_MAX;
                uint256 protocolFeePart = (exactAmount * protocolPart) / FEE_MAX;
                s.profit[referralAddress][token] += referralFeePart;
                s.profit[address(this)][token] += protocolFeePart;

                return exactAmount - referralFeePart - protocolFeePart;
            }
        }
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
            balanceOutBeforeLastSwap = IERC20(tokenOut).balanceOf(address(this));
        }

        bool zeroForOne = tokenIn < tokenOut;

        // cast a uint256 to a int256, revert on overflow
        // https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/SafeCast.sol#L24
        if (amountIn > CAST_INT_CONSTANT) {
            revert MultiswapRouterComponent_InvalidIntCast();
        }

        // caching pool address in storage
        _getLocalStorage().poolAddressCache = address(pool);
        (int256 amount0, int256 amount1) = pool.swap(
            destination,
            zeroForOne,
            int256(amountIn),
            (zeroForOne ? MIN_SQRT_RATIO_PLUS_ONE : MAX_SQRT_RATIO_MINUS_ONE),
            abi.encode(tokenIn)
        );

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
            balanceOutBeforeLastSwap = IERC20(tokenOut).balanceOf(address(this));
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
                amountInput = IERC20(tokenIn).balanceOf(address(pair)) - reserveInput;
            }

            // get the output number of tokens after swap
            amountOutput = HelperLib.getAmountOut(amountInput, reserveInput, reserveOutput, fee);
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
    function _wrapNative() internal returns (bool isNative) {
        isNative = msg.value > 0;

        if (isNative) {
            _wrappedNative.deposit{ value: msg.value }();
        }
    }

    /// @dev sends tokens or unwrap and send native
    function _sendTokens(bool isNative, address token, uint256 amount, bool unwrap, address to) internal {
        if (isNative && unwrap) {
            _wrappedNative.withdraw(amount);
            TransferHelper.safeTransferNative(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }
}
