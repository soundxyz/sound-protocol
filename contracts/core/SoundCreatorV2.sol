// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Clones } from "openzeppelin/proxy/Clones.sol";
import { ReentrancyGuard } from "openzeppelin/security/ReentrancyGuard.sol";
import { ISoundCreatorV2 } from "./interfaces/ISoundCreatorV2.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";

/**
 * @title SoundCreatorV1
 * @notice A factory that deploys minimal proxies of SoundEditions.
 * @dev The proxies are OpenZeppelin's Clones implementation of https://eips.ethereum.org/EIPS/eip-1167
 */
contract SoundCreatorV2 is ISoundCreatorV2, EIP712, ReentrancyGuard {
    using LibBitmap for LibBitmap.Bitmap;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev For EIP-712 signature digest calculation.
     */
    bytes32 public constant SOUND_CREATION_TYPEHASH =
        // prettier-ignore
        keccak256(
            "SoundCreation("
                "address implementation,"
                "address owner,"
                "bytes32 salt,"
                "bytes initData,"
                "address[] contracts,"
                "bytes[] data,"
                "uint256 nonce"
            ")"
        );

    /**
     * @dev For EIP-712 signature digest calculation.
     */
    bytes32 public constant DOMAIN_TYPEHASH = _DOMAIN_TYPEHASH;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev For storing the invalidated nonces.
     */
    mapping(address => LibBitmap.Bitmap) internal _invalidatedNonces;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function create(SoundCreation calldata c) external nonReentrant returns (address edition, bytes[] memory results) {
        if (c.owner != LibMulticaller.sender()) revert Unauthorized();
        (edition, results) = _create(c);
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function createWithSignature(SoundCreation calldata creation, bytes calldata signature)
        external
        nonReentrant
        returns (address soundEdition, bytes[] memory results)
    {
        (soundEdition, results) = _createWithSignature(creation, signature);
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function mint(
        address minter,
        bytes calldata mintData,
        address refundTo
    ) external payable nonReentrant {
        _mint(minter, mintData, refundTo);
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function createWithSignatureAndMint(
        SoundCreation calldata c,
        bytes calldata signature,
        address minter,
        bytes calldata mintData,
        address refundTo
    ) external payable nonReentrant returns (address edition, bytes[] memory results) {
        // We will skip the `createWithSignature` if the SoundEdtion already exists.
        (, bool exists) = soundEditionAddress(c.implementation, c.owner, c.salt);
        if (!exists) (edition, results) = _createWithSignature(c, signature);
        _mint(minter, mintData, refundTo);
    }

    /**
     * @inheritdoc ISoundCreatorV2
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
     * @dev For compressed calldata calling.
     */
    fallback() external payable {
        LibZip.cdFallback();
    }

    /**
     * @dev For compressed calldata calling.
     */
    receive() external payable {
        LibZip.cdFallback();
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function soundEditionAddress(
        address implementation,
        address owner,
        bytes32 salt
    ) public view returns (address addr, bool exists) {
        addr = Clones.predictDeterministicAddress(implementation, _saltedSalt(owner, salt), address(this));
        exists = addr.code.length != 0;
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function isValidSignature(SoundCreation calldata c, bytes calldata signature) public view returns (bool) {
        return
            // Whether the signature is correctly signed. Will revert if recovery fails.
            SignatureCheckerLib.isValidSignatureNowCalldata(c.owner, computeDigest(c), signature) &&
            // And whether the creation's nonce is not invalidated.
            !_invalidatedNonces[c.owner].get(c.nonce);
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function computeDigest(SoundCreation calldata c) public view returns (bytes32) {
        bytes32 encodedDataHash;
        unchecked {
            bytes[] calldata cData = c.data;
            uint256 n = cData.length;
            bytes32[] memory encodedData = new bytes32[](n);
            for (uint256 i = 0; i != n; ++i) {
                encodedData[i] = keccak256(cData[i]);
            }
            encodedDataHash = keccak256(abi.encodePacked(encodedData));
        }
        return
            _hashTypedData(
                keccak256(
                    abi.encode(
                        SOUND_CREATION_TYPEHASH,
                        c.implementation, // address
                        c.owner, // address
                        c.salt, // bytes32
                        keccak256(c.initData), // bytes
                        keccak256(abi.encodePacked(c.contracts)), // address[]
                        encodedDataHash, // bytes[]
                        c.nonce // uint256
                    )
                )
            );
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function noncesInvalidated(address signer, uint256[] calldata nonces) external view returns (bool[] memory result) {
        unchecked {
            result = new bool[](nonces.length);
            LibBitmap.Bitmap storage s = _invalidatedNonces[signer];
            for (uint256 i; i != nonces.length; ++i) {
                result[i] = s.get(nonces[i]);
            }
        }
    }

    // EIP712 parameters.

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function name() external pure returns (string memory name_) {
        (name_, ) = _domainNameAndVersion();
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function version() external pure returns (string memory version_) {
        (, version_) = _domainNameAndVersion();
    }

    /**
     * @inheritdoc ISoundCreatorV2
     */
    function domainSeparator() external view returns (bytes32 separator) {
        separator = _domainSeparator();
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
        name_ = "SoundCreator";
        version_ = "2";
    }

    /**
     * @dev Call the `contracts` in order with `data`.
     * @param contracts The addresses of the contracts.
     * @param data      The `abi.encodeWithSelector` calldata for each of the contracts.
     * @return results The results of calling the contracts.
     */
    function _callContracts(address[] calldata contracts, bytes[] calldata data)
        internal
        returns (bytes[] memory results)
    {
        if (contracts.length != data.length) revert ArrayLengthsMismatch();

        assembly {
            // Grab the free memory pointer.
            // We will use the free memory to construct the `results` array,
            // and also as a temporary space for the calldata.
            results := mload(0x40)
            // Set `results.length` to be equal to `data.length`.
            mstore(results, data.length)
            // Skip the first word, which is used to store the length
            let resultsOffsets := add(results, 0x20)
            // Compute the location of the last calldata offset in `data`.
            // `shl(5, n)` is a gas-saving shorthand for `mul(0x20, n)`.
            let dataOffsetsEnd := add(data.offset, shl(5, data.length))
            // This is the start of the unused free memory.
            // We use it to temporarily store the calldata to call the contracts.
            let m := add(resultsOffsets, shl(5, data.length))

            // Loop through `contacts` and `data` together.
            // prettier-ignore
            for { let i := data.offset } iszero(eq(i, dataOffsetsEnd)) { i := add(i, 0x20) } {
                // Location of `bytes[i]` in calldata.
                let o := add(data.offset, calldataload(i))
                // Copy `bytes[i]` from calldata to the free memory.
                calldatacopy(
                    m, // Start of the unused free memory.
                    add(o, 0x20), // Location of starting byte of `data[i]` in calldata.
                    calldataload(o) // The length of the `bytes[i]`.
                )
                // Grab `contracts[i]` from the calldata.
                // As `contracts` is the same length as `data`,
                // `sub(i, data.offset)` gives the relative offset to apply to
                // `contracts.offset` for `contracts[i]` to match `data[i]`.
                let c := calldataload(add(contracts.offset, sub(i, data.offset)))
                // Call the contract, and revert if the call fails.
                if iszero(
                    call(
                        gas(), // Gas remaining.
                        c, // `contracts[i]`.
                        0, // `msg.value` of the call: 0 ETH.
                        m, // Start of the copy of `bytes[i]` in memory.
                        calldataload(o), // The length of the `bytes[i]`.
                        0x00, // Start of output. Not used.
                        0x00 // Size of output. Not used.
                    )
                ) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                // Append the current `m` into `resultsOffsets`.
                mstore(resultsOffsets, m)
                resultsOffsets := add(resultsOffsets, 0x20)

                // Append the `returndatasize()` to `results`.
                mstore(m, returndatasize())
                // Append the return data to `results`.
                returndatacopy(add(m, 0x20), 0x00, returndatasize())
                // Advance `m` by `returndatasize() + 0x20`,
                // rounded up to the next multiple of 32.
                // `0x3f = 32 + 31`. The mask is `type(uint64).max & ~31`,
                // which is big enough for all purposes (see memory expansion costs).
                m := and(add(add(m, returndatasize()), 0x3f), 0xffffffffffffffe0)
            }
            // Allocate the memory for `results` by updating the free memory pointer.
            mstore(0x40, m)
        }
    }

    /**
     * @dev Returns the salted salt.
     *      To prevent griefing and accidental collisions from clients that don't
     *      generate their salt properly.
     * @param owner The initial owner of the SoundEdition.
     * @param salt  The salt, generated on the client side.
     * @return result The computed value.
     */
    function _saltedSalt(address owner, bytes32 salt) internal view returns (bytes32 result) {
        assembly {
            mstore(0x20, owner)
            mstore(0x0c, chainid())
            mstore(0x00, salt)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Creates a new SoundEdtion via `c.soundCreator`, and a new split contract if needed.
     * @param c The SoundCreation struct.
     * @return edition The address of the created SoundEdition contract.
     * @return results      The results of calling the contracts.
     *                      Use `abi.decode` to decode them.
     */
    function _create(SoundCreation calldata c) internal returns (address edition, bytes[] memory results) {
        if (c.implementation == address(0)) revert ImplementationAddressCantBeZero();

        // Create Sound Edition proxy.
        edition = payable(Clones.cloneDeterministic(c.implementation, _saltedSalt(c.owner, c.salt)));

        bytes calldata initData = c.initData;
        // Initialize proxy.
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `initData` to the free memory.
            calldatacopy(m, initData.offset, initData.length)
            // Call the initializer, and revert if the call fails.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    edition, // Address of the edition.
                    0, // `msg.value` of the call: 0 ETH.
                    m, // Start of input.
                    initData.length, // Length of input.
                    0x00, // Start of output. Not used.
                    0x00 // Size of output. Not used.
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }

        results = _callContracts(c.contracts, c.data);

        Ownable(edition).transferOwnership(c.owner);

        emit Created(c.implementation, edition, c.owner, c.initData, c.contracts, c.data, results);
    }

    /**
     * @dev Creates a SoundEdition on behalf of `c.owner`.
     * @param c  The SoundCreation struct.
     * @param signature The signature for the SoundCreation struct, by `c.owner`.
     * @return edition The address of the created SoundEdition contract.
     * @return results      The results of calling the contracts.
     *                      Use `abi.decode` to decode them.
     */
    function _createWithSignature(SoundCreation calldata c, bytes calldata signature)
        internal
        returns (address edition, bytes[] memory results)
    {
        if (!isValidSignature(c, signature)) revert InvalidSignature();
        (edition, results) = _create(c);

        // Invalidate the nonce and emit the event.
        _invalidatedNonces[c.owner].set(c.nonce);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = c.nonce;
        emit NoncesInvalidated(c.owner, nonces);
    }

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
    function _mint(
        address minter,
        bytes calldata mintData,
        address refundTo
    ) internal {
        if (minter == address(0)) return;
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `mintData` into the free memory.
            calldatacopy(m, mintData.offset, mintData.length)
            // Make a call to `minter` with `mintData`, reverting if the call fails.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    minter, // Address of the minter.
                    callvalue(), // All the ETH sent to this function.
                    m, // Start of the `mintData` in memory.
                    mintData.length, // Length of `mintData`.
                    0x00, // We'll use returndatasize instead.
                    0x00 // We'll use returndatasize instead.
                )
            ) {
                // If the call fails, bubble up the revert.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
        if (refundTo != address(0)) {
            // Refund any ETH in this contract. In the unlikely case where ETH is
            // mistakenly sent to this contract, it will be combined into the refund.
            if (address(this).balance != 0) {
                if (refundTo == address(1)) refundTo = msg.sender;
                SafeTransferLib.forceSafeTransferAllETH(refundTo);
            }
        }
    }
}
