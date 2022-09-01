// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IFixedPriceSignatureMinter, EditionMintData, MintInfo } from "./interfaces/IFixedPriceSignatureMinter.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title IFixedPriceSignatureMinter
 * @dev Module for fixed-price, signature-authorizd mints of Sound editions.
 * @author Sound.xyz
 */
contract FixedPriceSignatureMinter is IFixedPriceSignatureMinter, BaseMinter {
    using ECDSA for bytes32;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev EIP-712 Typed structured data hash (used for checking signature validity).
     *      https://eips.ethereum.org/EIPS/eip-712
     */
    bytes32 public constant MINT_TYPEHASH =
        keccak256(
            "EditionInfo(address buyer,uint256 mintId,uint32 claimTicket,uint32 quantityLimit,address affiliate)"
        );

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     *      `edition` => `mintId` => EditionMintData
     */
    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    /**
     * @dev A bitmap where each bit representing whether the ticket has been claimed.
     *      `edition` => `mintId` => `index` => bit array
     */
    mapping(address => mapping(uint128 => mapping(uint256 => uint256))) internal _claimsBitmaps;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) public returns (uint128 mintId) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.signer = signer;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit FixedPriceSignatureMintCreated(
            edition,
            mintId,
            price,
            signer,
            maxMintable,
            startTime,
            endTime,
            affiliateFeeBPS
        );
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes calldata signature,
        uint32 claimTicket
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, data.maxMintable);

        _validateAndClaimSignature(signature, data.signer, claimTicket, edition, mintId, signedQuantity, affiliate);

        _mint(edition, mintId, quantity, affiliate);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Won't overflow, as `price` is 96 bits, and `quantity` is 32 bits.
            return _editionMintData[edition][mintId].price * quantity;
        }
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mintInfo(address edition, uint128 mintId) public view override returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintable,
            type(uint32).max, // maxMintablePerAccount
            mintData.totalMinted,
            mintData.signer
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IFixedPriceSignatureMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IFixedPriceSignatureMinter).interfaceId;
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function checkClaimTickets(
        address edition,
        uint128 mintId,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory claimed) {
        claimed = new bool[](claimTickets.length);
        // Will not overflow due to max block gas limit bounding the size of `claimTickets`.
        unchecked {
            for (uint256 i = 0; i < claimTickets.length; i++) {
                (uint256 storedBit, , , ) = _getBitForClaimTicket(edition, mintId, claimTickets[i]);
                claimed[i] = storedBit == 1;
            }
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Validates and claims the signed message required to mint.
     * @param signature      The signed message to authorize the mint.
     * @param expectedSigner The address of the signer that authorizes mints.
     * @param claimTicket    The ticket number to enforce single-use of the signature.
     * @param edition        The edition address.
     * @param mintId         The mint instance ID.
     * @param signedQuantity The max quantity this buyer has been approved to mint.
     * @param affiliate      The affiliate address.
     */
    function _validateAndClaimSignature(
        bytes calldata signature,
        address expectedSigner,
        uint32 claimTicket,
        address edition,
        uint128 mintId,
        uint32 signedQuantity,
        address affiliate
    ) private {
        (
            uint256 storedBit,
            uint256 ticketGroup,
            uint256 ticketGroupOffset,
            uint256 ticketGroupIdx
        ) = _getBitForClaimTicket(edition, mintId, claimTicket);

        if (storedBit != 0) revert SignatureAlreadyUsed();

        // Flip the bit to 1 to indicate that the ticket has been claimed
        _claimsBitmaps[edition][mintId][ticketGroupIdx] = ticketGroup | (uint256(1) << ticketGroupOffset);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ISoundEditionV1(edition).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(MINT_TYPEHASH, msg.sender, mintId, claimTicket, signedQuantity, affiliate))
            )
        );

        if (digest.recover(signature) != expectedSigner) revert InvalidSignature();
    }

    /**
     * @dev Gets the bit variables associated with a ticket number
     * @param edition      The edition address.
     * @param mintId       The mint instance ID.
     * @param claimTicket The ticket number.
     * @return ticketGroup       The bit array for this ticket number.
     * @return ticketGroupIdx    The index of the the local group.
     * @return ticketGroupOffset The offset/index for the ticket number in the local group.
     * @return storedBit         The stored bit at this ticket number's index within the local group.
     */
    function _getBitForClaimTicket(
        address edition,
        uint128 mintId,
        uint32 claimTicket
    )
        private
        view
        returns (
            uint256 ticketGroup,
            uint256 ticketGroupIdx,
            uint256 ticketGroupOffset,
            uint256 storedBit
        )
    {
        unchecked {
            ticketGroupIdx = claimTicket >> 8;
            ticketGroupOffset = claimTicket & 255;
        }

        // cache the local group for efficiency
        ticketGroup = _claimsBitmaps[edition][mintId][ticketGroupIdx];

        // gets the stored bit
        storedBit = (ticketGroup >> ticketGroupOffset) & uint256(1);

        return (storedBit, ticketGroup, ticketGroupOffset, ticketGroupIdx);
    }
}
