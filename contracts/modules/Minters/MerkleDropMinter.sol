// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/utils/structs/BitMaps.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

/// @dev Airdrop using merkle tree logic.
contract MerkleDropMinter is MintControllerBase {
    using BitMaps for BitMaps.BitMap;
    BitMaps.BitMap private claimed;

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

    function mint(address edition, uint256 mintId, uint32 quantity, bytes32[] calldata merkleProof) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        _requireMintOpen(data.startTime, data.endTime);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, quantity));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        require(valid, "Invalid proof");

        _mint(edition, mintId, msg.sender, quantity, data.price * quantity);

        // require(!isClaimed(index), "Tokens already claimed");
        // claimed.set(index);

        emit DropClaimed(msg.sender, quantity);

        // require(
        //     IERC20(token).transfer(recipient, quantity),
        //     "Airdrop: Claim failed"
        // );

        ISoundEditionV1(edition).mint{ value: msg.value }(edition, quantity);
    }

    /**
     * @dev Returns true if the claim at the given index in the merkle tree has already been made.
     * @param index The index into the merkle tree.
     */
    function isClaimed(uint256 index) public view returns (bool) {
        return claimed.get(index);
    }
}
