// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "openzeppelin/utils/structs/EnumerableMap.sol";
import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

/// @dev Airdrop using merkle tree logic.
contract MerkleDropMinter is MintControllerBase {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // prettier-ignore
    event MerkleDropMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable
    );

    event DropClaimed(
      address recipient,
      uint32 quantity
    );

    error ExceedsEligibleQuantity();

    error InvalidMerkleProof();

    struct EditionMintData {
        // Hash of the root node for the merkle tree drop
        bytes32 merkleRootHash;
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // End timestamp of sale (in seconds since unix epoch).
        uint32 endTime;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
        // Tracking claimed amounts per wallet
        EnumerableMap.AddressToUintMap claimed;
    }

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable
    ) public returns (uint256 mintId) {
        mintId = _createEditionMintController(edition);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.merkleRootHash = merkleRootHash;
        data.price = price;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            mintId,
            merkleRootHash,
            price,
            startTime,
            endTime,
            maxMintable
        );
    }

    /**
     * @dev Deletes a given edition's mint configuration.
     * @param edition Address of the edition.
     * @param mintId The mint instance identifier, created when the mint controller was set.
     */
    function deleteEditionMint(address edition, uint256 mintId) public {
        _deleteEditionMintController(edition, mintId);
        delete _editionMintData[edition][mintId];
    }

    /**
     * @dev Returns the given edition's mint configuration.
     * This returns all the `EditionMintData` struct properties except for `claimed`
     * EnumerableMap.AddressToUintMap.
     * To get the claimed map, use `getClaimed` function.
     * @param edition Address of the edition.
     * @param mintId Mint identifier.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 totalMinted) {
            EditionMintData storage data = _editionMintData[edition][mintId];
            return (
                data.merkleRootHash,
                data.price,
                data.startTime,
                data.endTime,
                data.maxMintable,
                data.totalMinted
            );
    }

    /*
     * @dev Mints tokens.
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId Id of the mint instance.
     * @param eligibleQuantity The total number of tokens allocated to the user.
     * This is the maximum the user can claim.
     * @param requestedQuantity Number of tokens to actually mint. This can be anything up to the `eligibleQuantity`
     * @param merkleProof Merkle proof for the claim.
     */
    function mint(address edition, uint256 mintId, uint32 eligibleQuantity, uint32 requestedQuantity, bytes32[] calldata merkleProof) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 nextTotalMinted = data.totalMinted + requestedQuantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        _requireMintOpen(data.startTime, data.endTime);

        uint256 updatedClaimedQuantity = getClaimed(edition, mintId, msg.sender) + requestedQuantity;

        if (updatedClaimedQuantity > eligibleQuantity) revert ExceedsEligibleQuantity();

        // Update the claimed amount data
        data.claimed.set(msg.sender, updatedClaimedQuantity);

        bytes32 leaf = keccak256(abi.encodePacked(edition, msg.sender, eligibleQuantity));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        if (!valid) revert InvalidMerkleProof();

        _mint(edition, mintId, msg.sender, requestedQuantity, data.price * requestedQuantity);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    /**
     * @dev Returns the amount of claimed tokens for `wallet` in `mintData`.
     * @param edition Address of the edition.
     * @param mintId Mint identifier.
     * @param wallet Address of the wallet.
     * @return claimedQuantity is defaulted to 0 when the wallet address key is not found
     * in the `claimed` map.
     */
    function getClaimed(address edition, uint256 mintId, address wallet) public view returns (uint256) {
        EditionMintData storage data = _editionMintData[edition][mintId];
        (bool success, uint256 claimedQuantity) = data.claimed.tryGet(wallet);
        claimedQuantity = success ? claimedQuantity : 0;
        return claimedQuantity;
    }
}
