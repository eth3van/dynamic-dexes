// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { TransferHelper } from "../libraries/TransferHelper.sol";

import { TransientStorageComponentLibrary } from "../../libraries/TransientStorageComponentLibrary.sol";
import { FeeLibrary } from "../../libraries/FeeLibrary.sol";

import { ISymbiosis } from "./interfaces/ISymbiosis.sol";
import { ISymbiosisComponent } from "./interfaces/ISymbiosisComponent.sol";

/// @title SymbiosisComponent
contract SymbiosisComponent is ISymbiosisComponent {
    using TransferHelper for address;

    // =========================
    // immutable storage
    // =========================

    ISymbiosis internal immutable _portal;

    // =========================
    // constructor
    // =========================

    constructor(address portal_) {
        _portal = ISymbiosis(portal_);
    }

    // =========================
    // getters
    // =========================

    /// @inheritdoc ISymbiosisComponent
    function portal() external view returns (address) {
        return address(_portal);
    }

    // =========================
    // main function
    // =========================

    /// @inheritdoc ISymbiosisComponent
    function sendSymbiosis(ISymbiosisComponent.SymbiosisTransaction calldata symbiosisTransaction) external {
        address sender = TransientStorageComponentLibrary.getSenderAddress();
        (address token, uint256 amount) = TransientStorageComponentLibrary.getTokenAndAmount();
        if (token == address(0) && amount == 0) {
            TransferHelper.safeTransferFrom({
                token: symbiosisTransaction.rtoken,
                from: sender,
                to: address(this),
                value: symbiosisTransaction.amount
            });
        }

        amount = FeeLibrary.payFee({ token: symbiosisTransaction.rtoken, amount: symbiosisTransaction.amount });

        symbiosisTransaction.rtoken.safeApprove({ spender: address(_portal), value: amount });

        _portal.metaSynthesize({
            _metaSynthesizeTransaction: ISymbiosis.MetaSynthesizeTransaction({
                stableBridgingFee: symbiosisTransaction.stableBridgingFee,
                amount: amount,
                rtoken: symbiosisTransaction.rtoken,
                chain2address: symbiosisTransaction.chain2address,
                receiveSide: 0xb8f275fBf7A959F4BCE59999A2EF122A099e81A8, // Synthesis on BOBA BNB
                oppositeBridge: 0x5523985926Aa12BA58DC5Ad00DDca99678D7227E, // BridgeV2 on BOBA BNB
                syntCaller: sender,
                chainID: 56_288, // Boba BNB
                swapTokens: symbiosisTransaction.swapTokens,
                secondDexRouter: 0xcB28fbE3E9C0FEA62E0E63ff3f232CECfE555aD4, // MulticallRouter on BOBA BNB
                secondSwapCalldata: symbiosisTransaction.secondSwapCalldata,
                finalReceiveSide: symbiosisTransaction.finalReceiveSide,
                finalCalldata: symbiosisTransaction.finalCalldata,
                finalOffset: symbiosisTransaction.finalOffset,
                revertableAddress: symbiosisTransaction.chain2address,
                clientID: bytes32("Dynamic")
            })
        });
    }
}
