// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title CoreActions
 * @dev The registry for social core actions.
 */
interface ICoreActions {
    // =============================================================
    //                           STRUCTS
    // =============================================================

    /**
     * @dev A struct containing the arguments for registering core actions.
     */
    struct CoreActionRegistrations {
        // The platform.
        address platform;
        // The core action type.
        uint256 coreActionType;
        // The list of targets.
        address[] targets;
        // The list of lists of timestamps. Must have the same dimensions as `actors`.
        address[][] actors;
        // The list of lists of timestamps. Must have the same dimensions as `actors`.
        uint32[][] timestamps;
        // The nonce of the signature (per platform's signer).
        uint256 nonce;
        // A signature by the current `platform` signer to authorize registration.
        bytes signature;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when `actor` performs a core action with `target`,
     *      of `coreActionType`, on `platform`, at `timestamp`.
     * @param platform        The platform address.
     * @param coreActionType  The core action type.
     * @param target          The core action target.
     * @param actor           The core action actor.
     * @param timestamp       The core action timestamp.
     */
    event Interacted(
        address indexed platform,
        uint256 coreActionType,
        address indexed target,
        address indexed actor,
        uint32 timestamp
    );

    /**
     * @dev Emitted when the `nonces` of `signer` are invalidated.
     * @param signer  The signer of the nonces.
     * @param nonces The nonces.
     */
    event NoncesInvalidated(address indexed signer, uint256[] nonces);

    /**
     * @dev Emitted when the signer for a platform is set.
     * @param platform The platform address.
     * @param signer   The signer for the platform.
     */
    event PlatformSignerSet(address indexed platform, address signer);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev The length of the input arrays must be the same.
     */
    error ArrayLengthsMismatch();

    /**
     * @dev The timestamp cannot be zero.
     */
    error TimestampIsZero();

    /**
     * @dev The query range exceeds the bounds.
     */
    error InvalidQueryRange();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Registers a batch of core actions.
     * @param r The core actions to register.
     * @return targetAliases A list of aliases corresponding to `targets`.
     * @return actorAliases  A list of aliases corresponding to `actors`.
     */
    function register(CoreActionRegistrations memory r)
        external
        returns (address[] memory targetAliases, address[][] memory actorAliases);

    /**
     * @dev Allows the platform to set their signer.
     * @param signer The signer for the platform.
     */
    function setPlatformSigner(address signer) external;

    /**
     * @dev Invalidates the nonces for the `msg.sender`.
     * @param nonces The nonces.
     */
    function invalidateNonces(uint256[] calldata nonces) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the CoreActionRegistrations struct's EIP-712 typehash.
     * @return The constant value.
     */
    function CORE_ACTION_REGISTRATIONS_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev Returns the configured signer for `platform`.
     * @param platform The platform.
     * @return The configured value.
     */
    function platformSigner(address platform) external view returns (address);

    /**
     * @dev Returns whether each of the `nonces` of `signer` has been invalidated.
     * @param signer The signer of the signature.
     * @param nonces An array of nonces.
     * @return A bool array representing whether each nonce has been invalidated.
     */
    function noncesInvalidated(address signer, uint256[] calldata nonces) external view returns (bool[] memory);

    /**
     * @dev Returns the core action timestamp of `actor` on target`,
     *      of `coreActionType`, on `platform`.
     * @param platform The platform.
     * @param coreActionType  The core action type.
     * @param target          The core action target.
     * @param actor           The actor
     * @return The amped timestamp value.
     */
    function getCoreActionTimestamp(
        address platform,
        uint256 coreActionType,
        address target,
        address actor
    ) external view returns (uint32);

    /**
     * @dev Returns the number of core actions on `target`,
     *      of `coreActionType` on `platform`.
     * @param platform        The platform.
     * @param coreActionType  The core action type.
     * @param target          The core action target.
     * @return The latest value.
     */
    function numCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) external view returns (uint256);

    /**
     * @dev Returns the list of `actors` and `timestamps`
     *      for coreActions on `target`, of `coreActionType`, on `platform`.
     * @param platform The platform.
     * @param coreActionType The core action type.
     * @param target         The core action target.
     * @return actors     The actors for the coreActions.
     * @return timestamps The timestamps of the coreActions.
     */
    function getCoreActions(
        address platform,
        uint256 coreActionType,
        address target
    ) external view returns (address[] memory actors, uint32[] memory timestamps);

    /**
     * @dev Returns the list of `actors` and `timestamps`
     *      for coreActions on `target`, of `coreActionType`, on `platform`.
     * @param platform The platform.
     * @param coreActionType The core action type.
     * @param target          The core action target.
     * @param start           The start index of the range.
     * @param stop            The end index of the range (exclusive).
     * @return actors     The actors for the coreActions.
     * @return timestamps The timestamps of the coreActions.
     */
    function getCoreActionsIn(
        address platform,
        uint256 coreActionType,
        address target,
        uint256 start,
        uint256 stop
    ) external view returns (address[] memory actors, uint32[] memory timestamps);
}
