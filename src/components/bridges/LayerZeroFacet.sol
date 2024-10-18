// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Ownable } from "../../external/Ownable.sol";

import {
    ILayerZeroEndpointV2, UlnConfig, Origin, MessagingFee, MessagingParams
} from "./stargate/ILayerZeroEndpointV2.sol";
import { IMessageLibManager } from "./stargate/IMessageLibManager.sol";
import { ISendLib } from "./stargate/ISendLib.sol";

import { TransientStorageComponentLibrary } from "../../libraries/TransientStorageComponentLibrary.sol";

import { ILayerZeroComponent } from "./interfaces/ILayerZeroComponent.sol";

/// @title LayerZeroComponent
contract LayerZeroComponent is Ownable, ILayerZeroComponent {
    // =========================
    // immutable storage
    // =========================

    /// @dev LayerZeroV2 endpoint
    ILayerZeroEndpointV2 internal immutable _endpointV2;

    // =========================
    // storage
    // =========================

    struct LayerZeroComponentStorage {
        /// @dev trusted peers, default - address(this)
        mapping(uint32 eid => bytes32 peer) peers;
        /// @dev gas limit lookup
        mapping(uint32 eid => uint128 gasLimit) gasLimitLookup;
        /// @dev default gas limit
        uint128 defaultGasLimit;
    }

    /// @dev Storage position for the layerZero component, to avoid collisions in storage.
    /// @dev Uses the "magic" constant to find a unique storage slot.
    // keccak256("layerZero.storage")
    bytes32 private constant LAYERZERO_COMPONENT_STORAGE =
        0x7f8156d470b4ca2c59b150cce6693dce9d231528b9e476a0fbfb17f10e0dab09;

    /// @dev Returns the storage slot for the LayerZeroComponent.
    /// @dev This function utilizes inline assembly to directly access the desired storage position.
    ///
    /// @return s The storage slot pointer for the LayerZeroComponent.
    function _getLocalStorage() internal pure returns (LayerZeroComponentStorage storage s) {
        assembly ("memory-safe") {
            s.slot := LAYERZERO_COMPONENT_STORAGE
        }
    }

    // =========================
    // constructor
    // =========================

    constructor(address endpointV2) {
        _endpointV2 = ILayerZeroEndpointV2(endpointV2);
    }

    // =========================
    // getters
    // =========================

    /// @inheritdoc ILayerZeroComponent
    function eid() external view returns (uint32) {
        return _endpointV2.eid();
    }

    /// @inheritdoc ILayerZeroComponent
    function defaultGasLimit() external view returns (uint128) {
        return _getLocalStorage().defaultGasLimit;
    }

    /// @inheritdoc ILayerZeroComponent
    function getPeer(uint32 remoteEid) external view returns (bytes32 trustedRemote) {
        return _getPeer(remoteEid);
    }

    /// @inheritdoc ILayerZeroComponent
    function getGasLimit(uint32 remoteEid) external view returns (uint128 gasLimit) {
        gasLimit = _getGasLimit(remoteEid);
    }

    /// @inheritdoc ILayerZeroComponent
    function getDelegate() external view returns (address) {
        return _endpointV2.delegates({ oapp: address(this) });
    }

    /// @inheritdoc ILayerZeroComponent
    function getUlnConfig(address lib, uint32 remoteEid) external view returns (UlnConfig memory) {
        bytes memory config = _endpointV2.getConfig({ oapp: address(this), lib: lib, eid: remoteEid, configType: 2 });

        return abi.decode(config, (UlnConfig));
    }

    /// @inheritdoc ILayerZeroComponent
    function getNativeSendCap(uint32 remoteEid) external view returns (uint128 nativeCap) {
        (,,, nativeCap) = ISendLib(
            ISendLib(_endpointV2.getSendLibrary({ sender: address(this), dstEid: remoteEid })).getExecutorConfig({
                oapp: address(this),
                remoteEid: remoteEid
            }).executor
        ).dstConfig({ dstEid: remoteEid });
    }

    /// @inheritdoc ILayerZeroComponent
    function isSupportedEid(uint32 remoteEid) external view returns (bool) {
        return _endpointV2.isSupportedEid({ eid: remoteEid });
    }

    /// @inheritdoc ILayerZeroComponent
    function estimateFee(
        uint32 remoteEid,
        uint128 nativeAmount,
        address to
    )
        external
        view
        returns (uint256 nativeFee)
    {
        unchecked {
            return _quote(remoteEid, _createNativeDropOption(remoteEid, nativeAmount, to));
        }
    }

    // =========================
    // admin methods
    // =========================

    /// @inheritdoc ILayerZeroComponent
    function setPeers(uint32[] calldata remoteEids, bytes32[] calldata remoteAddresses) external onlyOwner {
        uint256 length = remoteEids.length;
        if (length != remoteAddresses.length) {
            revert ILayerZeroComponent.LayerZeroComponent_LengthMismatch();
        }

        LayerZeroComponentStorage storage s = _getLocalStorage();

        for (uint256 i; i < length;) {
            s.peers[remoteEids[i]] = remoteAddresses[i];

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ILayerZeroComponent
    function setGasLimit(uint32[] calldata remoteEids, uint128[] calldata gasLimits) external onlyOwner {
        if (remoteEids.length != gasLimits.length) {
            revert ILayerZeroComponent.LayerZeroComponent_LengthMismatch();
        }

        LayerZeroComponentStorage storage s = _getLocalStorage();

        for (uint256 i; i < remoteEids.length;) {
            s.gasLimitLookup[remoteEids[i]] = gasLimits[i];

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ILayerZeroComponent
    function setDefaultGasLimit(uint128 newDefaultGasLimit) external onlyOwner {
        _getLocalStorage().defaultGasLimit = newDefaultGasLimit;
    }

    /// @inheritdoc ILayerZeroComponent
    function setDelegate(address delegate) external onlyOwner {
        _endpointV2.setDelegate({ delegate: delegate });
    }

    /// @inheritdoc ILayerZeroComponent
    function setUlnConfigs(address lib, uint64 confirmations, uint32[] calldata eids, address dvn) external onlyOwner {
        uint256 length = eids.length;

        IMessageLibManager.SetConfigParam[] memory configs = new IMessageLibManager.SetConfigParam[](length);

        for (uint256 i; i < length; i++) {
            address[] memory opt = new address[](0);
            address[] memory req = new address[](1);
            req[0] = dvn;

            bytes memory config = abi.encode(
                UlnConfig({
                    confirmations: confirmations,
                    requiredDVNCount: uint8(1),
                    optionalDVNCount: 0,
                    optionalDVNThreshold: 0,
                    requiredDVNs: req,
                    optionalDVNs: opt
                })
            );
            configs[i] = IMessageLibManager.SetConfigParam({ eid: eids[i], configType: 2, config: config });

            unchecked {
                ++i;
            }
        }

        IMessageLibManager(address(_endpointV2)).setConfig({ oapp: address(this), lib: lib, params: configs });
    }

    // =========================
    // main
    // =========================

    /// @inheritdoc ILayerZeroComponent
    function sendDeposit(uint32 remoteEid, uint128 nativeDrop, address to) external payable {
        address sender = TransientStorageComponentLibrary.getSenderAddress();

        bytes memory options = _createNativeDropOption(remoteEid, nativeDrop, to > address(0) ? to : sender);

        uint256 fee = _quote(remoteEid, options);

        if (fee > address(this).balance) {
            revert ILayerZeroComponent.LayerZeroComponent_FeeNotMet();
        }

        _endpointV2.send{ value: fee }({
            params: MessagingParams({
                dstEid: remoteEid,
                receiver: _getPeer(remoteEid),
                message: bytes(""),
                options: options,
                payInLzToken: false
            }),
            refundAddress: sender
        });
    }

    // =========================
    // receive
    // =========================

    /// @inheritdoc ILayerZeroComponent
    function nextNonce(uint32, bytes32) external pure returns (uint64) {
        return 0;
    }

    /// @inheritdoc ILayerZeroComponent
    function allowInitializePath(Origin calldata origin) external view returns (bool) {
        return _getPeer(origin.srcEid) == origin.sender;
    }

    /// @inheritdoc ILayerZeroComponent
    function lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) external pure {
        return;
    }

    // =========================
    // internal
    // =========================

    /// @dev Creates native drop options for passed `nativeAmount` and `to`.
    function _createNativeDropOption(
        uint32 remoteEid,
        uint128 nativeAmount,
        address to
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 _to;

        assembly {
            _to := to
        }

        return abi.encodePacked(
            abi.encodePacked(
                // uint16(3) - type
                // uint8(1) - worker id
                // uint16(17) - payload length
                // uint8(1) - lzReceive type
                uint48(0x00301001101),
                _getGasLimit(remoteEid)
            ),
            // uint8(1) - worker id
            // uint16(49) - payload length
            // uint8(2) - native drop type
            uint32(0x01003102),
            nativeAmount,
            _to
        );
    }

    /// @dev Calculates fee in native token for passed options.
    function _quote(uint32 remoteEid, bytes memory options) internal view returns (uint256 nativeFee) {
        MessagingFee memory fee = _endpointV2.quote({
            params: MessagingParams({
                dstEid: remoteEid,
                receiver: _getPeer(remoteEid),
                message: bytes(""),
                options: options,
                payInLzToken: false
            }),
            sender: address(this)
        });

        return fee.nativeFee;
    }

    /// @dev Helper method for get peer for passed remoteEid.
    function _getPeer(uint32 remoteEid) internal view returns (bytes32 trustedRemote) {
        trustedRemote = _getLocalStorage().peers[remoteEid];
        if (trustedRemote == 0) {
            assembly {
                trustedRemote := address()
            }
        }
    }

    /// @dev Helper method for get gasLimit for passed remoteEid.
    function _getGasLimit(uint32 remoteEid) internal view returns (uint128 gasLimit) {
        LayerZeroComponentStorage storage s = _getLocalStorage();

        gasLimit = s.gasLimitLookup[remoteEid];
        if (gasLimit == 0) {
            gasLimit = s.defaultGasLimit;
        }
    }
}
