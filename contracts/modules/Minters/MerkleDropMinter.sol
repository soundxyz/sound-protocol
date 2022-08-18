// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "openzeppelin/utils/structs/EnumerableMap.sol";
import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

/// @dev Airdrop using merkle tree logic.
contract MerkleDropMinter is MintControllerBase {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // ================================
    // EVENTS
    // ================================

    // prettier-ignore
    event MerkleDropMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxAllowedPerWallet
    );

    event DropClaimed(address recipient, uint32 quantity);

    // ================================
    // ERRORS
    // ================================

    error InvalidMerkleProof();

    // ================================
    // STRUCTS
    // ================================

    struct EditionMintData {
        // Hash of the root node for the merkle tree drop
        bytes32 merkleRootHash;
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The maximum number of tokens that a wallet can mint.
        uint32 maxAllowedPerWallet;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    // ================================
    // STORAGE
    // ================================

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Initializes the configuration for an edition merkle drop mint.
     * @param edition Address of the song edition contract we are minting for.
     * @param merkleRootHash bytes32 hash of the Merkle tree representing eligible mints.
     * @param price_ Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintable_ The maximum number of tokens that can can be minted for this sale.
     * @param maxAllowedPerWallet The maximum number of tokens that a single wallet can mint.
     */
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint256 price_,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable_,
        uint32 maxAllowedPerWallet
    ) public returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime, maxAllowedPerWallet);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.merkleRootHash = merkleRootHash;
        data.price = price_;
        data.maxMintable = maxMintable_;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            mintId,
            merkleRootHash,
            price_,
            startTime,
            endTime,
            maxMintable_,
            maxAllowedPerWallet
        );
    }

    /*
     * @dev Mints tokens.
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId Id of the mint instance.
     * This is the maximum the user can claim.
     * @param requestedQuantity Number of tokens to actually mint. This can be anything up to the `maxAllowedPerWallet`
     * @param merkleProof Merkle proof for the claim.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 nextTotalMinted = data.totalMinted + requestedQuantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        bytes32 leaf = keccak256(abi.encodePacked(edition, msg.sender));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        if (!valid) revert InvalidMerkleProof();

        _mint(edition, mintId, msg.sender, requestedQuantity, data.price * requestedQuantity);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the `EditionMintData` for `edition.
     * @param edition Address of the song edition contract we are minting for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    function price(address edition, uint256 mintId) public view returns (uint256) {
        return _editionMintData[edition][mintId].price;
    }

    function maxMintable(address edition, uint256 mintId) public view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintable;
    }
}
