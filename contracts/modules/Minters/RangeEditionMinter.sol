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

    error OutOfPermissionedSlots();

    error TicketNumberExceedsMax();

    error TicketNumberUsed();

    error NotPermissionedMint();

    error MintPaused();

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxPermissioned
    );

    event StartTimeSet(address indexed edition, uint32 indexed startTime);

    event EndTimeSet(address indexed edition, uint32 indexed endTime);

    event SignerSet(address indexed edition, address indexed signerAddress);

    event PausedSet(address indexed edition, bool indexed paused);

    event MaxPermissionedSet(address indexed edition, uint32 indexed maxPermissioned);

    // The permissioned typehash (used for checking signature validity)
    bytes32 public constant PERMISSIONED_SALE_TYPEHASH =
        keccak256('EditionInfo(address contractAddress,address buyerAddress,uint256 editionId,uint256 ticketNumber)');
    
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
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // Maximum number of permissioned tokens that can be minted.
        uint32 maxPermissioned;
        // Whether the sale is paused.
        bool paused;
    }

    mapping(address => EditionMintData) public editionMintData;

    mapping(address => LibBitmap.Bitmap) internal _ticketClaimedBitmaps;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(keccak256('EIP712Domain(uint256 chainId)'), block.chainid));
    }

    function createEditionMint(
        address edition,
        uint256 price,
        address signer,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxPermissioned
    ) public {
        _createEditionMintController(edition);
        if (maxMintable == 0) revert MaxMintableIsZero();
        if (endTime <= startTime) revert InvalidTimeRange();
        if (maxPermissioned != 0 && signer == address(0)) revert SignerIsZeroAddress();

        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.signer = signer;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        data.maxPermissioned = maxPermissioned;

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            price,
            signer,
            startTime,
            endTime,
            maxMintable,
            maxPermissioned
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
        EditionMintData storage data = editionMintData[edition];

        if (data.paused) revert MintPaused();
        
        if (data.startTime > block.timestamp) {

            if (data.totalMinted >= data.maxPermissioned) revert OutOfPermissionedSlots();

            _claimTicketNumbers(edition, ticketNumbers, signature, data.signer);
        } else {

            if ((data.totalMinted += quantity) > data.maxMintable) revert SoldOut();
        }
        if (data.price * quantity != msg.value) revert WrongEtherValue();

        ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
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
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMISSIONED_SALE_TYPEHASH, 
                        address(this), 
                        msg.sender, 
                        edition, 
                        ticketNumbers
                    )
                )
            )
        );
        bool isValidSignature = digest.recover(signature) == signer && signer != address(0);
        if (!isValidSignature) revert InvalidSignature();
    }

    function setStartTime(address edition, uint32 startTime) public onlyEditionMintController(edition) {
        editionMintData[edition].startTime = startTime;
        emit StartTimeSet(edition, startTime);
    }

    function setEndTime(address edition, uint32 endTime) public onlyEditionMintController(edition) {
        editionMintData[edition].endTime = endTime;
        emit EndTimeSet(edition, endTime);
    }

    function setMaxPermissioned(address edition, uint32 maxPermissioned) public onlyEditionMintController(edition) {
        if (editionMintData[edition].signer == address(0)) revert NotPermissionedMint();
        editionMintData[edition].maxPermissioned = maxPermissioned;
        emit MaxPermissionedSet(edition, maxPermissioned);
    }

    function setSigner(address edition, address signer) public onlyEditionMintController(edition) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        editionMintData[edition].signer = signer;
        emit SignerSet(edition, signer);
    }

    function setPaused(address edition, bool paused) public onlyEditionMintController(edition) {
        editionMintData[edition].paused = paused;
        emit PausedSet(edition, paused);
    }
}
