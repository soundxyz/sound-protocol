// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a fixed-price signature mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint96 price;
    // Whitelist signer address.
    address signer;
    // The maximum number of tokens that can can be minted for this sale.
    uint32 maxMintable;
    // The total number of tokens minted so far for this sale.
    uint32 totalMinted;
}

/**
 * @dev All the information about a fixed-price signature mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    address signer;
}

/**
 * @title IFixedPriceSignatureMinter
 * @dev Interface for the `FixedPriceSignatureMinter` module.
 * @author Sound.xyz
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a new fixed price signature mint is created.
     * @param edition         The edition address.
     * @param mintId          The mint ID.
     * @param signer          The address of the signer that authorizes mints.
     * @param maxMintable     The maximum number of tokens that can be minted.
     * @param startTime       The time minting can begin.
     * @param endTime         The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    /**
     * @dev Emitted when the `maxMintable` is changed for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintable The maximum number of tokens that can be minted on this schedule.
     */
    event MaxMintableSet(address indexed edition, uint128 indexed mintId, uint32 maxMintable);

    /**
     * @dev Emitted when the `price` is changed for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param price   Sale price in ETH for minting a single token in `edition`.
     */
    event PriceSet(address indexed edition, uint128 indexed mintId, uint96 price);

    /**
     * @dev Emitted when the `signer` is changed for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param signer  The address of the signer that authorizes mints.
     */
    event SignerSet(address indexed edition, uint128 indexed mintId, address signer);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Cannot mint more than the signed quantity.
     */
    error ExceedsSignedQuantity();

    /**
     * @dev The signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev The mint sigature can only be used a single time.
     */
    error SignatureAlreadyUsed();

    /**
     * @dev The signer can't be the zero address.
     */
    error SignerIsZeroAddress();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes a fixed-price signature mint instance.
     * @param edition         The edition address.
     * @param price           The price to mint a token.
     * @param signer          The address of the signer that authorizes mints.
     * @param maxMintable_    The maximum number of tokens that can be minted.
     * @param startTime       The time minting can begin.
     * @param endTime         The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId         The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) external returns (uint128 mintId);

    /**
     * @dev Mints a token for a particular mint instance.
     * @param mintId         The mint ID.
     * @param quantity       The quantity of tokens to mint.
     * @param signedQuantity The max quantity this buyer has been approved to mint.
     * @param affiliate      The affiliate address.
     * @param signature      The signed message to authorize the mint.
     * @param claimTicket    The ticket number to enforce single-use of the signature.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes calldata signature,
        uint32 claimTicket
    ) external payable;

    /*
     * @dev Sets the `maxMintable` for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintable The maximum number of tokens that can be minted on this schedule.
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) external;

    /*
     * @dev Sets the `price` for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param price   Sale price in ETH for minting a single token in `edition`.
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) external;

    /*
     * @dev Sets the `maxMintablePerAccount` for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param signer  The address of the signer that authorizes mints.
     */
    function setSigner(
        address edition,
        uint128 mintId,
        address signer
    ) external;

    // =============================================================
    //               PUBLIC / EXTERNAL READ FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the EIP-712 type hash of the signature for minting.
     * @return typeHash The constant value.
     */
    function MINT_TYPEHASH() external view returns (bytes32 typeHash);

    /**
     * @dev Returns IFixedPriceSignatureMinter.MintInfo instance containing the full minter parameter set.
     * @param edition   The edition to get the mint instance for.
     * @param mintId    The ID of the mint instance.
     * @return Information about this mint.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);

    /**
     * @dev Returns an array of booleans on whether each claim ticket has been claimed.
     * @param edition      The edition to get the mint instance for.
     * @param mintId       The ID of the mint instance.
     * @param claimTickets The claim tickets to check.
     * @return claimed The computed values.
     */
    function checkClaimTickets(
        address edition,
        uint128 mintId,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory claimed);

    /**
     * @dev Returns the EIP-712 domain separator of the signature for minting.
     * @return separator The constant value.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32 separator);
}
