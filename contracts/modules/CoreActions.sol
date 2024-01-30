// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ICoreActions } from "@modules/interfaces/ICoreActions.sol";
import { IAddressAliasRegistry } from "@modules/interfaces/IAddressAliasRegistry.sol";
import { EnumerableMap } from "openzeppelin/utils/structs/EnumerableMap.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { LibOps } from "@core/utils/LibOps.sol";

/**
 * @title CoreActions
 * @dev The registry for social coreActions.
 */
contract CoreActions is ICoreActions, EIP712 {
    using LibBitmap for LibBitmap.Bitmap;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev For EIP-712 signature digest calculation.
     */
    bytes32 public constant CORE_ACTION_REGISTRATIONS_TYPEHASH =
        // prettier-ignore
        keccak256(
            "CoreActionRegistrations("
                "uint256 coreActionType,"
                "address[] targets,"
                "address[][] actors,"
                "uint256[][] timestamps,"
                "uint256 nonce"
            ")"
        );

    // =============================================================
    //                          IMMUTABLES
    // =============================================================

    /**
     * @dev The address alias registry.
     */
    address public immutable addressAliasRegistry;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Mapping of `platform` => `coreActionType` => `target` => `actor` => `timestamp`.
     */
    mapping(address => mapping(uint256 => mapping(address => EnumerableMap.AddressToUintMap))) internal _coreActions;

    /**
     * @dev For storing the invalidated nonces.
     */
    mapping(address => LibBitmap.Bitmap) internal _invalidatedNonces;

    /**
     * @dev A mapping of `platform` => `platformSigner`.
     */
    mapping(address => address) public platformSigner;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address addressAliasRegistry_) payable {
        addressAliasRegistry = addressAliasRegistry_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ICoreActions
     */
    function register(CoreActionRegistrations calldata r)
        external
        returns (address[] memory targetAliases, address[][] memory actorAliases)
    {
        uint256 n = r.targets.length;
        address[] memory resolvedTargets;
        address[][] memory resolvedActors = new address[][](n);
        actorAliases = new address[][](n);

        // Check input array lengths and resolve aliases.
        unchecked {
            if (n != r.actors.length) revert ArrayLengthsMismatch();
            if (n != r.timestamps.length) revert ArrayLengthsMismatch();

            IAddressAliasRegistry registry = IAddressAliasRegistry(addressAliasRegistry);
            (resolvedTargets, targetAliases) = registry.resolveAndRegister(r.targets);

            for (uint256 i; i != n; ++i) {
                if (r.actors[i].length != r.timestamps[i].length) revert ArrayLengthsMismatch();
                (resolvedActors[i], actorAliases[i]) = registry.resolveAndRegister(actorAliases[i]);
            }
        }

        // Check the signature and invalidate the nonce.
        unchecked {
            bytes32 digest = _hashTypedData(
                keccak256(
                    abi.encode(
                        CORE_ACTION_REGISTRATIONS_TYPEHASH,
                        r.coreActionType, // uint256
                        _hashOf(resolvedTargets), // address[]
                        _hashOf(resolvedActors), // address[][]
                        _hashOf(r.timestamps), // uint256[][]
                        r.nonce // uint256
                    )
                )
            );

            address signer = platformSigner[r.platform];
            if (!SignatureCheckerLib.isValidSignatureNowCalldata(signer, digest, r.signature))
                revert InvalidSignature();
            if (!_invalidatedNonces[signer].toggle(r.nonce)) revert InvalidSignature();

            uint256[] memory nonces = new uint256[](1);
            nonces[0] = r.nonce;
            emit NoncesInvalidated(signer, nonces);
        }

        // Store and emit events.
        unchecked {
            for (uint256 i; i != r.targets.length; ++i) {
                address target = r.targets[i];
                EnumerableMap.AddressToUintMap storage m = _coreActions[r.platform][r.coreActionType][target];
                for (uint256 j; j != r.actors[i].length; ++j) {
                    address actor = r.actors[i][j];
                    if (!m.contains(actor)) {
                        uint256 timestamp = r.timestamps[i][j];
                        m.set(actor, timestamp);
                        emit Interacted(r.platform, r.coreActionType, target, actor, timestamp);
                    }
                }
            }
        }
    }

    /**
     * @inheritdoc ICoreActions
     */
    function invalidateNonces(uint256[] calldata nonces) external {
        unchecked {
            address sender = LibMulticaller.sender();
            LibBitmap.Bitmap storage s = _invalidatedNonces[sender];
            for (uint256 i; i != nonces.length; ++i) {
                s.set(nonces[i]);
            }
            emit NoncesInvalidated(sender, nonces);
        }
    }

    /**
     * @inheritdoc ICoreActions
     */
    function setPlatformSigner(address signer) public {
        address sender = LibMulticaller.senderOrSigner();
        platformSigner[sender] = signer;
        emit PlatformSignerSet(sender, signer);
    }

    // Misc functions:
    // ---------------

    /**
     * @dev For calldata compression.
     */
    fallback() external payable {
        LibZip.cdFallback();
    }

    /**
     * @dev For calldata compression.
     */
    receive() external payable {
        LibZip.cdFallback();
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ICoreActions
     */
    function noncesInvalidated(address signer, uint256[] calldata nonces) public view returns (bool[] memory result) {
        unchecked {
            result = new bool[](nonces.length);
            LibBitmap.Bitmap storage s = _invalidatedNonces[signer];
            for (uint256 i; i != nonces.length; ++i) {
                result[i] = s.get(nonces[i]);
            }
        }
    }

    /**
     * @inheritdoc ICoreActions
     */
    function getCoreActionTimestamp(
        address platform,
        uint256 coreActionType,
        address target,
        address actor
    ) public view returns (uint256) {
        return _coreActions[platform][coreActionType][target].get(actor);
    }

    /**
     * @inheritdoc ICoreActions
     */
    function numCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) public view returns (uint256) {
        return _coreActions[platform][coreActionType][target].length();
    }

    /**
     * @inheritdoc ICoreActions
     */
    function getCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) public view returns (address[] memory actors, uint256[] memory timestamps) {
        EnumerableMap.AddressToUintMap storage m = _coreActions[platform][coreActionType][target];
        return getCoreActionsIn(platform, coreActionType, target, 0, m.length());
    }

    /**
     * @inheritdoc ICoreActions
     */
    function getCoreActionsIn(
        address platform,
        uint256 coreActionType,
        address target,
        uint256 start,
        uint256 stop
    ) public view returns (address[] memory actors, uint256[] memory timestamps) {
        EnumerableMap.AddressToUintMap storage m = _coreActions[platform][coreActionType][target];
        unchecked {
            uint256 l = stop - start;
            uint256 n = m.length();
            if (LibOps.or(start > stop, stop > n)) revert InvalidQueryRange();
            actors = new address[](l);
            timestamps = new uint256[](l);
            for (uint256 i; i != l; ++i) {
                (actors[i], timestamps[i]) = m.at(start + i);
            }
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Override for EIP-712.
     * @return name_    The EIP-712 name.
     * @return version_ The EIP-712 version.
     */
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory name_, string memory version_)
    {
        name_ = "CoreActions";
        version_ = "1";
    }

    /**
     * @dev Returns the hash of `a`.
     */
    function _hashOf(address[] memory a) internal pure freeTempMemory returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    /**
     * @dev Returns the hash of `a`.
     */
    function _hashOf(address[][] memory a) internal pure freeTempMemory returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }

    /**
     * @dev Returns the hash of `a`.
     */
    function _hashOf(uint256[][] calldata a) internal pure freeTempMemory returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }

    /**
     * @dev Frees all memory allocated within the scope of the function.
     */
    modifier freeTempMemory() {
        bytes32 m;
        assembly {
            m := mload(0x40)
        }
        _;
        assembly {
            mstore(0x40, m)
        }
    }
}
