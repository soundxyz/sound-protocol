// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";
import "solady/utils/ECDSA.sol";
import "solady/utils/LibBitmap.sol";
import "solady/utils/Multicallable.sol";

/// @dev Minter class for range edition sales.
contract RangedEditionMinter is MintControllerBase, Multicallable {
    using ECDSA for bytes32;
    using LibBitmap for LibBitmap.Bitmap;

    error SignerIsZeroAddress();

    error MaxMintableIsZero();

    error InvalidTimeRange();

    error WrongEtherValue();

    error SoldOut();

    error InvalidSignature();

    error NoPermissionedSlots();

    error InvalidTicketNumbers();

    error SignerNotSet();

    error MintPaused();

    error MaxPermissionedMintableExceedsMaxMintable();

    error MintHasEnded();

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

    event StartTimeSet(address indexed edition, uint32 indexed startTime);

    event EndTimeSet(address indexed edition, uint32 indexed endTime);

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

        // Invariant: if `maxPermissionedMintable != 0`, `signer != address(0)`.
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
        uint256[] calldata ticketNumbers,
        bytes calldata signature
    ) public payable {
        unchecked {
            EditionMintData storage data = editionMintData[edition];

            // Require not paused.
            if (data.paused) revert MintPaused();
            // Require exact payment.
            if (data.price * quantity != msg.value) revert WrongEtherValue();
            // Require not ended.
            if (data.endTime > block.timestamp) revert MintHasEnded();

            // If the public sale has not started, we perform permissioned sale.
            if (data.startTime > block.timestamp) {
                // Increase `totalPermissionedMinted` by `quantity`.
                // Require that the increased value does not exceed `maxPermissionedMintable`.
                if ((data.totalPermissionedMinted += quantity) > data.maxPermissionedMintable)
                    revert NoPermissionedSlots();

                // Recover signer. Returns `address(0)` if signature is invalid.
                address recovered = keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR,
                        keccak256(
                            abi.encode(PERMISSIONED_SALE_TYPEHASH, address(this), msg.sender, edition, ticketNumbers)
                        )
                    )
                ).recover(signature);
                // Invariant: if `maxPermissionedMintable != 0`, `signer != address(0)`.
                // If `maxPermissionedMintable == 0`, the previous check will have reverted.
                // Therefore, `signer` will not be the zero address here.
                if (recovered != data.signer) revert InvalidSignature();

                // Claim tickets.
                LibBitmap.Bitmap storage ticketClaimedBitmap = _ticketClaimedBitmaps[edition];
                for (uint256 i; i < ticketNumbers.length; ++i) {
                    uint256 ticketNumber = ticketNumbers[i];
                    if (ticketNumber > type(uint32).max) revert InvalidTicketNumbers();
                    if (ticketClaimedBitmap.get(ticketNumber)) revert InvalidTicketNumbers();
                    ticketClaimedBitmap.set(ticketNumber);
                }
                // Require that the number of `ticketNumbers` equals `quantity`.
                if (ticketNumbers.length != quantity) revert InvalidTicketNumbers();
            }
            // Increase `totalMinted` by `quantity`.
            // Require that the increased value does not exceed `maxMintable`.
            if ((data.totalMinted += quantity) > data.maxMintable) revert SoldOut();

            ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
        }
    }

    function setStartTime(address edition, uint32 startTime) public onlyEditionMintController(edition) {
        if (editionMintData[edition].endTime <= startTime) revert InvalidTimeRange();
        editionMintData[edition].startTime = startTime;
        emit StartTimeSet(edition, startTime);
    }

    function setEndTime(address edition, uint32 endTime) public onlyEditionMintController(edition) {
        if (endTime <= editionMintData[edition].startTime) revert InvalidTimeRange();
        editionMintData[edition].endTime = endTime;
        emit EndTimeSet(edition, endTime);
    }

    function setMaxPermissionedMintable(address edition, uint32 maxPermissionedMintable)
        public
        onlyEditionMintController(edition)
    {
        // Invariant: if `maxPermissionedMintable != 0`, `signer != address(0)`.
        // Reject all updates to `maxPermissionedMintable` (which may be non-zero),
        // when the stored `signer` is the zero address.
        if (editionMintData[edition].signer == address(0)) revert SignerNotSet();
        if (maxPermissionedMintable > editionMintData[edition].maxMintable)
            revert MaxPermissionedMintableExceedsMaxMintable();
        editionMintData[edition].maxPermissionedMintable = maxPermissionedMintable;
        emit MaxPermissionedMintableSet(edition, maxPermissionedMintable);
    }

    function setMaxMintable(address edition, uint32 maxMintable) public onlyEditionMintController(edition) {
        if (editionMintData[edition].maxPermissionedMintable > maxMintable)
            revert MaxPermissionedMintableExceedsMaxMintable();
        editionMintData[edition].maxMintable = maxMintable;
        emit MaxMintableSet(edition, maxMintable);
    }

    function setSigner(address edition, address signer) public onlyEditionMintController(edition) {
        // Invariant: if `maxPermissionedMintable != 0`, `signer != address(0)`.
        // Reject all attempts to set `signer` to the zero address,
        // as the stored `maxPermissionedMintable` may not be zero.
        if (signer == address(0)) revert SignerIsZeroAddress();
        editionMintData[edition].signer = signer;
        emit SignerSet(edition, signer);
    }

    function setPaused(address edition, bool paused) public onlyEditionMintController(edition) {
        editionMintData[edition].paused = paused;
        emit PausedSet(edition, paused);
    }
}
