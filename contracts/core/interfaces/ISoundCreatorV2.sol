// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title ISoundCreatorV2
 * @notice The interface for the Sound edition factory.
 */
interface ISoundCreatorV2 {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev A struct containing all the data required for creating a SoundEdition
     *      and setting up all other relevant contracts.
     */
    struct SoundCreation {
        // The address of the SoundEdition implementation.
        address implementation;
        // The initial owner of the deployed SoundEdition.
        address owner;
        // The salt used for deploying the SoundEdition via the SoundCreator factory.
        bytes32 salt;
        // The calldata passed to the SoundEdition to initialize it.
        bytes initData;
        // Array of contracts to call after initializing the SoundEdition.
        address[] contracts;
        // Array of abi encoded calldata to pass to each entry in `contracts`.
        bytes[] data;
        // The current nonce used to sign the SoundCreation struct, if required.
        // Just generate some really random number on the client side for this.
        uint256 nonce;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when an edition is created.
     * @param implementation The address of the SoundEdition implementation.
     * @param edition        The address of the deployed SoundEdition.
     * @param owner          The address of the owner.
     * @param initData       The calldata to initialize SoundEdition via `abi.encodeWithSelector`.
     * @param contracts      The list of contracts called.
     * @param data           The list of calldata created via `abi.encodeWithSelector`
     * @param results        The results of calling the contracts. Use `abi.decode` to decode them.
     */
    event Created(
        address indexed implementation,
        address indexed edition,
        address indexed owner,
        bytes initData,
        address[] contracts,
        bytes[] data,
        bytes[] results
    );

    /**
     * @dev Emitted when the `nonces` of `signer` are invalidated.
     * @param signer  The signer of the nonces.
     * @param nonces The nonces.
     */
    event NoncesInvalidated(address indexed signer, uint256[] nonces);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Thrown if the implementation address is zero.
     */
    error ImplementationAddressCantBeZero();

    /**
     * @dev Thrown if the lengths of the input arrays are not equal.
     */
    error ArrayLengthsMismatch();

    /**
     * @dev Not authorized to perfrom the action.
     */
    error Unauthorized();

    /**
     * @dev The signature for the SoundCreation struct is invalid.
     *      This could be caused be an invalid parameter, signer, or invalidated nonce.
     */
    error InvalidSignature();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a SoundEdition and sets up all other relevant contracts.
     * @param creation The SoundCreation struct.
     * @return soundEdition The address of the created SoundEdition contract.
     * @return results      The results of calling the contracts.
     *                      Use `abi.decode` to decode them.
     */
    function create(SoundCreation calldata creation) external returns (address soundEdition, bytes[] memory results);

    /**
     * @dev Creates a SoundEdition on behalf of `creation.owner`.
     * @param creation  The SoundCreation struct.
     * @param signature The signature for the SoundCreation struct, by `creation.owner`.
     * @return soundEdition The address of the created SoundEdition contract.
     * @return results      The results of calling the contracts.
     *                      Use `abi.decode` to decode them.
     */
    function createWithSignature(SoundCreation calldata creation, bytes calldata signature)
        external
        returns (address soundEdition, bytes[] memory results);

    /**
     * @dev Calls `minter` with `mintData`.
     *      After which, refunds any remaining ETH balance in the adapter contract.
     *      If `minter` is the zero address, the function is a no-op.
     * @param minter   The minter contract to call, SAM included.
     * @param mintData The abi encoded calldata to the minter contract.
     * @param refundTo The address to transfer any remaining ETH in the contract after the calls.
     *                 If `address(0)`, remaining ETH will NOT be refunded.
     *                 If `address(1)`, remaining ETH will be refunded to `msg.sender`.
     *                 If anything else, remaining ETH will be refunded to `refundTo`.
     */
    function mint(
        address minter,
        bytes calldata mintData,
        address refundTo
    ) external payable;

    /**
     * @dev Equivalent to calling {createWithSignature}, followed by {mint}.
     * @param creation  The SoundCreation struct.
     * @param signature The signature for the SoundCreation struct, by `creation.owner`.
     * @param minter    The minter contract to call, SAM included.
     * @param mintData  The calldata to the minter contract.
     * @param refundTo  The address to transfer any remaining ETH in the contract after the calls.
     *                  If `address(0)`, remaining ETH will NOT be refunded.
     *                  If `address(1)`, remaining ETH will be refunded to `msg.sender`.
     *                  If anything else, remaining ETH will be refunded to `refundTo`.
     * @return soundEdition The address of the created SoundEdition contract.
     * @return results      The results of calling the contracts.
     *                      Use `abi.decode` to decode them.
     */
    function createWithSignatureAndMint(
        SoundCreation calldata creation,
        bytes calldata signature,
        address minter,
        bytes calldata mintData,
        address refundTo
    ) external payable returns (address soundEdition, bytes[] memory results);

    /**
     * @dev Invalidates the nonces for the `msg.sender`.
     * @param nonces The nonces.
     */
    function invalidateNonces(uint256[] calldata nonces) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns whether each of the `nonces` of `signer` has been invalidated.
     * @param signer The signer of the signature.
     * @param nonces An array of nonces.
     * @return A bool array representing whether each nonce has been invalidated.
     */
    function noncesInvalidated(address signer, uint256[] calldata nonces) external view returns (bool[] memory);

    /**
     * @dev Returns the deterministic address for the SoundEdition clone.
     * @param implementation The implementation of the SoundEdition.
     * @param owner          The initial owner of the SoundEdition.
     * @param salt           The salt, generated on the client side.
     * @return addr The computed address.
     * @return exists Whether the contract exists.
     */
    function soundEditionAddress(
        address implementation,
        address owner,
        bytes32 salt
    ) external view returns (address addr, bool exists);

    /**
     * @dev Returns if the signature for the creation struct is correctly signed,
     *      as well as the creation's nonce is still valid.
     * @param creation  The SoundCreation struct.
     * @param signature The signature for the SoundCreation struct.
     * @return isValid The computed result.
     */
    function isValidSignature(SoundCreation calldata creation, bytes calldata signature) external view returns (bool);

    /**
     * @dev Computes the EIP-712 hash of the SoundCreation struct.
     * @param creation The SoundCreation struct.
     * @return digest The computed result.
     */
    function computeDigest(SoundCreation calldata creation) external view returns (bytes32 digest);

    /**
     * @dev Returns the SoundCreation struct's EIP-712 typehash.
     * @return The constant value.
     */
    function SOUND_CREATION_TYPEHASH() external view returns (bytes32);

    /**
     * @dev Returns the EIP-712 domain typehash.
     * @return The constant value.
     */
    function DOMAIN_TYPEHASH() external view returns (bytes32);

    /**
     * @dev Returns the EIP-712 domain name.
     * @return name_ The constant value.
     */
    function name() external pure returns (string memory name_);

    /**
     * @dev Returns the EIP-712 domain version.
     * @return version_ The constant value.
     */
    function version() external pure returns (string memory version_);

    /**
     * @dev Returns the EIP-712 domain separator.
     * @return The current value.
     */
    function domainSeparator() external view returns (bytes32);
}
