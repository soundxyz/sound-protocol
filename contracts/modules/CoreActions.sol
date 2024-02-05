// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ICoreActions } from "@modules/interfaces/ICoreActions.sol";
import { IAddressAliasRegistry } from "@modules/interfaces/IAddressAliasRegistry.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibMap } from "solady/utils/LibMap.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";

/**
 * @title CoreActions
 * @dev The registry for social coreActions.
 */
contract CoreActions is ICoreActions, EIP712 {
    using LibBitmap for LibBitmap.Bitmap;
    using LibMap for LibMap.Uint32Map;

    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev Storage struct for storing mapping from `actors` => `timestamps`.
     */
    struct ActorsAndTimestamps {
        // Number of entries, for enumeration.
        uint256 length;
        // `actorAlias` => `timestamp`.
        LibMap.Uint32Map timestamps;
        // `index` => `actorAlias`.
        LibMap.Uint32Map actorAliases;
    }

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
                "uint32[][] timestamps,"
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
     * @dev Mapping of `platform` => `coreActionType` => `target` => `actorAndTimestamps`.
     */
    mapping(address => mapping(uint256 => mapping(address => ActorsAndTimestamps))) internal _coreActions;

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
        _validateArrayLengths(r);

        uint256 n = r.targets.length;
        address[] memory resolvedTargets;
        address[][] memory resolvedActors = new address[][](n);
        actorAliases = new address[][](n);

        // Resolve and register aliases.
        unchecked {
            IAddressAliasRegistry registry = IAddressAliasRegistry(addressAliasRegistry);
            (resolvedTargets, targetAliases) = registry.resolveAndRegister(r.targets);
            for (uint256 i; i != n; ++i) {
                (resolvedActors[i], actorAliases[i]) = registry.resolveAndRegister(r.actors[i]);
            }
        }

        // Check the signature and invalidate the nonce.
        {
            bytes32 digest = _computeDigest(r, resolvedTargets, resolvedActors);

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
            for (uint256 i; i != n; ++i) {
                address target = resolvedTargets[i];
                ActorsAndTimestamps storage m = _coreActions[r.platform][r.coreActionType][target];
                for (uint256 j; j != resolvedActors[i].length; ++j) {
                    uint32 actorAlias = uint32(uint160(actorAliases[i][j]));
                    if (m.timestamps.get(uint256(actorAlias)) == 0) {
                        uint32 timestamp = r.timestamps[i][j];
                        if (timestamp == 0) revert TimestampIsZero();
                        m.timestamps.set(actorAlias, timestamp);
                        m.actorAliases.set(m.length++, actorAlias);
                        emit Interacted(r.platform, r.coreActionType, target, resolvedActors[i][j], timestamp);
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
    ) public view returns (uint32) {
        ActorsAndTimestamps storage m = _coreActions[platform][coreActionType][target];
        uint256 actorAlias = uint160(IAddressAliasRegistry(addressAliasRegistry).aliasOf(actor));
        return m.timestamps.get(actorAlias);
    }

    /**
     * @inheritdoc ICoreActions
     */
    function numCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) public view returns (uint256) {
        return _coreActions[platform][coreActionType][target].length;
    }

    /**
     * @inheritdoc ICoreActions
     */
    function getCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) public view returns (address[] memory actors, uint32[] memory timestamps) {
        ActorsAndTimestamps storage m = _coreActions[platform][coreActionType][target];
        return getCoreActionsIn(platform, coreActionType, target, 0, m.length);
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
    ) public view returns (address[] memory actors, uint32[] memory timestamps) {
        ActorsAndTimestamps storage m = _coreActions[platform][coreActionType][target];
        unchecked {
            uint256 l = stop - start;
            uint256 n = m.length;
            if (start > stop || stop > n) revert InvalidQueryRange();
            actors = new address[](l);
            timestamps = new uint32[](l);
            IAddressAliasRegistry registry = IAddressAliasRegistry(addressAliasRegistry);
            for (uint256 i; i != l; ++i) {
                uint32 actorAlias = m.actorAliases.get(start + i);
                actors[i] = registry.addressOf(address(uint160(actorAlias)));
                timestamps[i] = m.timestamps.get(actorAlias);
            }
        }
    }

    /**
     * @inheritdoc ICoreActions
     */
    function computeDigest(CoreActionRegistrations calldata r) external view returns (bytes32) {
        _validateArrayLengths(r);

        uint256 n = r.targets.length;
        address[] memory resolvedTargets;
        address[][] memory resolvedActors = new address[][](n);

        // Resolve aliases.
        unchecked {
            IAddressAliasRegistry registry = IAddressAliasRegistry(addressAliasRegistry);
            (resolvedTargets, ) = registry.resolve(r.targets);
            for (uint256 i; i != n; ++i) {
                if (r.actors[i].length != r.timestamps[i].length) revert ArrayLengthsMismatch();
                (resolvedActors[i], ) = registry.resolve(r.actors[i]);
            }
        }

        return _computeDigest(r, resolvedTargets, resolvedActors);
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Returns the digest for `r`, with `resolvedTargets` and `resolvedActors`.
     * @param r               The core actions to register.
     * @param resolvedTargets The list of resolved targets.
     * @param resolvedActors  The list of resolved actors.
     * @return The computed digest.
     */
    function _computeDigest(
        CoreActionRegistrations calldata r,
        address[] memory resolvedTargets,
        address[][] memory resolvedActors
    ) internal view returns (bytes32) {
        return
            _hashTypedData(
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
    }

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
     * @dev Validate the array lengths.
     * @param r The core actions to register.
     */
    function _validateArrayLengths(CoreActionRegistrations calldata r) internal pure {
        unchecked {
            uint256 n = r.targets.length;
            if (n != r.actors.length) revert ArrayLengthsMismatch();
            if (n != r.timestamps.length) revert ArrayLengthsMismatch();
            for (uint256 i; i != n; ++i) {
                if (r.actors[i].length != r.timestamps[i].length) revert ArrayLengthsMismatch();
            }
        }
    }

    /**
     * @dev Returns the hash of `a`.
     * @param a The input to hash.
     * @return result The hash.
     */
    function _hashOf(address[] memory a) internal pure returns (bytes32 result) {
        assembly {
            result := keccak256(add(0x20, a), shl(5, mload(a)))
        }
    }

    /**
     * @dev Returns the hash of `a`.
     * @param a The input to hash.
     * @return result The hash.
     */
    function _hashOf(address[][] memory a) internal pure returns (bytes32 result) {
        assembly {
            let m := mload(0x40)
            let n := shl(5, mload(a))
            // prettier-ignore
            for { let i := 0 } iszero(eq(i, n)) { i := add(i, 0x20) } {
                let o := mload(add(add(a, 0x20), i))
                mstore(add(m, i), keccak256(add(0x20, o), shl(5, mload(o))))
            }
            result := keccak256(m, n)
        }
    }

    /**
     * @dev Returns the hash of `a`.
     * @param a The input to hash.
     * @return result The hash.
     */
    function _hashOf(uint32[][] calldata a) internal pure returns (bytes32 result) {
        assembly {
            let m := mload(0x40)
            let n := shl(5, a.length)
            // prettier-ignore
            for { let i := 0 } iszero(eq(i, n)) { i := add(i, 0x20) } {
                let o := add(a.offset, calldataload(add(a.offset, i)))
                let p := add(m, i)
                calldatacopy(p, add(o, 0x20), shl(5, calldataload(o)))
                mstore(p, keccak256(p, shl(5, calldataload(o))))
            }
            result := keccak256(m, n)
        }
    }
}
