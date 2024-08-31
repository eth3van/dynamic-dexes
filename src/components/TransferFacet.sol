// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { TransferHelper } from "./libraries/TransferHelper.sol";
import { IWrappedNative } from "./interfaces/IWrappedNative.sol";

import { ITransferComponent } from "./interfaces/ITransferComponent.sol";

/// @title TransferComponent - Component for token transfers
contract TransferComponent is ITransferComponent {
    // =========================
    // storage
    // =========================

    /// @dev address of the WrappedNative contract for current chain
    IWrappedNative private immutable _wrappedNative;

    // =========================
    // constructor
    // =========================

    /// @notice Constructor
    constructor(address wrappedNative) {
        _wrappedNative = IWrappedNative(wrappedNative);
    }

    // =========================
    // functions
    // =========================

    /// @inheritdoc ITransferComponent
    function transferToken(address token, uint256 amount, address to) external returns (uint256) {
        if (amount > 0) {
            TransferHelper.safeTransfer({ token: token, to: to, value: amount });
        }

        return amount;
    }

    /// @inheritdoc ITransferComponent
    function transferNative(address to, uint256 amount) external returns (uint256) {
        if (amount > 0) {
            TransferHelper.safeTransferNative({ to: to, value: amount });
        }

        return amount;
    }

    /// @inheritdoc ITransferComponent
    function unwrapNative(uint256 amount) external returns (uint256) {
        if (amount > 0) {
            _wrappedNative.withdraw({ wad: amount });
        }

        return amount;
    }

    /// @inheritdoc ITransferComponent
    function unwrapNativeAndTransferTo(address to, uint256 amount) external returns (uint256) {
        if (amount > 0) {
            _wrappedNative.withdraw({ wad: amount });

            TransferHelper.safeTransferNative({ to: to, value: amount });
        }

        return amount;
    }
}
