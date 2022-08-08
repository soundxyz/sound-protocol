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


    error WrongEtherValue();

    error SoldOut();

    error MintNotStarted();

    error MintHasEnded();

    // prettier-ignore
    event MerkleDropMintCreated(
        address indexed edition,
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

    mapping(address => EditionMintData) public editionMintData;

    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable
    ) public {
        _createEditionMintController(edition);
        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            merkleRootHash,
            price,
            startTime,
            endTime,
            maxMintable
        );
    }

    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete editionMintData[edition];
    }

    function mint(address edition, uint32 quantity, bytes32[] calldata merkleProof) public payable {
        EditionMintData storage data = editionMintData[edition];
        //bytes32 leaf = keccak256(abi.encodePacked(msg.sender, quantity));

        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, keccak256(abi.encodePacked(msg.sender)));

        // (bool valid, uint256 index) = MerkleProof.verify(
        //     merkleProof,
        //     data.merkleRootHash,
        //     leaf
        // );
        require(valid, "Invalid proof");

        if ((data.totalMinted += quantity) > data.maxMintable) revert SoldOut();
        if (data.price * quantity != msg.value) revert WrongEtherValue();
        if (block.timestamp < data.startTime) revert MintNotStarted();
        if (data.endTime < block.timestamp) revert MintHasEnded();

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
