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
    EnumerableMap.AddressToUintMap private claimed;

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
     * @param edition Address of the edition.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    function mint(address edition, uint256 mintId, uint32 totalQuantity, uint32 wantedQuantity, bytes32[] calldata merkleProof) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 nextTotalMinted = data.totalMinted + wantedQuantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        _requireMintOpen(data.startTime, data.endTime);

        (bool success, uint256 claimedQuantity) = claimed.tryGet(msg.sender);
        claimedQuantity = success ? claimedQuantity : 0;
        uint256 updatedClaimedQuantity = claimedQuantity + wantedQuantity;

        if (updatedClaimedQuantity > totalQuantity) revert ExceedsEligibleQuantity();

        // Update the claimed amount data
        claimed.set(msg.sender, updatedClaimedQuantity);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalQuantity));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        require(valid, "Invalid proof");

        _mint(edition, mintId, msg.sender, wantedQuantity, data.price * wantedQuantity);

        emit DropClaimed(msg.sender, wantedQuantity);
    }

    /**
     * @dev Returns the amount of claimed tokens for `wallet`.
     * @param wallet Address of the wallet.
     */
    function getClaimed(address wallet) public view returns (bool, uint256) {
        return claimed.tryGet(wallet);
    }
}
