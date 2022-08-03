// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";
import "solady/utils/ECDSA.sol";
import "solady/utils/LibBitmap.sol";

/// @dev Minter class for range edition sales.
contract RangedEditionMinter is MintControllerBase {
    using ECDSA for bytes32;
    using LibBitmap for LibBitmap.Bitmap;

    error SignerIsZeroAddress();

    error MaxMintableIsZero();

    error InvalidTimeRange();

    error WrongEtherValue();

    error SoldOut();

    error InvalidSignature();

    error NoPermissionedSlots();

    error TicketNumberExceedsMax();

    error TicketNumberUsed();

    error SignerNotSet();

    error MintPaused();

    error MaxPermissionedMintableExceedsMaxMintable();

    error AuctionHasEnded();

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxPermissionedMintable
    );

    event TimeRangeSet(address indexed edition, uint32 indexed startTime, uint32 indexed endTime);

    event SignerSet(address indexed edition, address indexed signer);

    event PausedSet(address indexed edition, bool indexed paused);

    event MaxPermissionedMintableSet(address indexed edition, uint32 indexed maxPermissionedMintable);

    event MaxMintableSet(address indexed edition, uint32 indexed maxMintable);

    // The permissioned typehash (used for checking signature validity)
    bytes32 public constant PERMISSIONED_SALE_TYPEHASH =
        keccak256("EditionInfo(address contractAddress,address buyerAddress,uint256 editionId,uint256 ticketNumber)");

    // Domain separator - used to prevent replay attacks using signatures from different networks
    bytes32 public immutable DOMAIN_SEPARATOR;

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Whitelist signer address.
        address signer;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // End timestamp of sale (in seconds since unix epoch).
        uint32 endTime;
        // The total number of tokens minted. Includes permissioned mints.
        uint32 totalMinted;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The total number of permissioned tokens minted.
        uint32 totalPermissionedMinted;
        // Maximum number of permissioned tokens that can be minted.
        uint32 maxPermissionedMintable;
        // Whether the sale is paused.
        bool paused;
    }

    mapping(address => EditionMintData) public editionMintData;

    mapping(address => LibBitmap.Bitmap) internal _ticketClaimedBitmaps;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(keccak256("EIP712Domain(uint256 chainId)"), block.chainid));
    }

    function createEditionMint(
        address edition,
        uint256 price,
        address signer,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxPermissionedMintable
    ) public {
        _createEditionMintController(edition);

        if (maxMintable == 0) revert MaxMintableIsZero();

        if (endTime <= startTime) revert InvalidTimeRange();

        if (maxPermissionedMintable > maxMintable) revert MaxPermissionedMintableExceedsMaxMintable();

        // Invariant: if `maxPermissionedMintable > 0`, `signer != address(0)`.
        if (maxPermissionedMintable != 0) {
            if (signer == address(0)) revert SignerIsZeroAddress();
        }

        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.signer = signer;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        data.maxPermissionedMintable = maxPermissionedMintable;

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            price,
            signer,
            startTime,
            endTime,
            maxMintable,
            maxPermissionedMintable
        );
    }

    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete editionMintData[edition];
    }

    function mint(
        address edition,
        uint32 quantity,
        uint32[] calldata ticketNumbers,
        bytes calldata signature
    ) public payable {
        unchecked {
            EditionMintData storage data = editionMintData[edition];

            if (data.paused) revert MintPaused();

            if (data.price * quantity != msg.value) revert WrongEtherValue();

            if (data.endTime > block.timestamp) revert AuctionHasEnded();

            uint256 nextTotalMinted = data.totalMinted + quantity;

            // If the public auction has not started.
            if (data.startTime > block.timestamp) {
                uint256 nextTotalPermissionedMinted = data.totalPermissionedMinted + quantity;
                if (nextTotalPermissionedMinted > data.maxPermissionedMintable) revert NoPermissionedSlots();
                _claimTicketNumbers(edition, ticketNumbers, signature, data.signer);
                data.totalPermissionedMinted = uint32(nextTotalPermissionedMinted);
            }

            if (nextTotalMinted > data.maxMintable) revert SoldOut();

            data.totalMinted = uint32(nextTotalMinted);

            ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
        }
    }

    /// @notice Gets signer address to validate permissioned purchase.
    /// @param edition Edition contract address.
    /// @param ticketNumbers Ticket numbers to check.
    /// @param signature Signed message.
    /// @param signer Signer.
    /// @dev https://eips.ethereum.org/EIPS/eip-712
    function _claimTicketNumbers(
        address edition,
        uint32[] calldata ticketNumbers,
        bytes calldata signature,
        address signer
    ) private {
        unchecked {
            for (uint256 i; i < ticketNumbers.length; ++i) {
                uint256 ticketNumber = ticketNumbers[i];
                if (ticketNumber > type(uint32).max) revert TicketNumberExceedsMax();
                if (_ticketClaimedBitmaps[edition].get(ticketNumber)) revert TicketNumberUsed();
                _ticketClaimedBitmaps[edition].set(ticketNumber);
            }
        }

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMISSIONED_SALE_TYPEHASH, address(this), msg.sender, edition, ticketNumbers))
            )
        );

        if (digest.recover(signature) != signer) revert InvalidSignature();
    }

    function setTimeRange(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) public onlyEditionMintController(edition) {
        if (endTime <= startTime) revert InvalidTimeRange();
        editionMintData[edition].startTime = startTime;
        editionMintData[edition].endTime = endTime;
        emit TimeRangeSet(edition, startTime, endTime);
    }

    function setMaxPermissionedMintable(address edition, uint32 value) public onlyEditionMintController(edition) {
        // Invariant: if `maxPermissionedMintable > 0`, `signer != address(0)`.
        // If there is no `signer`, we cannot allow `maxPermissioned` to be set to a non-zero value.
        if (editionMintData[edition].signer == address(0)) revert SignerNotSet();
        if (value > editionMintData[edition].maxMintable) revert MaxPermissionedMintableExceedsMaxMintable();
        editionMintData[edition].maxPermissionedMintable = value;
        emit MaxPermissionedMintableSet(edition, value);
    }

    function setMaxMintable(address edition, uint32 value) public onlyEditionMintController(edition) {
        if (editionMintData[edition].maxPermissionedMintable > value)
            revert MaxPermissionedMintableExceedsMaxMintable();
        editionMintData[edition].maxMintable = value;
        emit MaxMintableSet(edition, value);
    }

    function setSigner(address edition, address value) public onlyEditionMintController(edition) {
        // Invariant: if `maxPermissionedMintable > 0`, `signer != address(0)`.
        // The `maxPermissionedMintable` may be non-zero, and we cannot allow
        // `signer` to be set to the zero address.
        if (value == address(0)) revert SignerIsZeroAddress();
        editionMintData[edition].signer = value;
        emit SignerSet(edition, value);
    }

    function setPaused(address edition, bool value) public onlyEditionMintController(edition) {
        editionMintData[edition].paused = value;
        emit PausedSet(edition, value);
    }
}
