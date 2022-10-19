// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundEditionV1a } from "@core/SoundEditionV1a.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { EditionMaxMinter } from "@modules/EditionMaxMinter.sol";
import { RarityShuffleMetadata } from "@modules/RarityShuffleMetadata.sol";

import { Merkle } from "murky/Merkle.sol";

contract Merkler is Script {
    address private MERKLE_MINTER = vm.envAddress("MERKLE_MINTER");
    uint256 public constant MINT_ID = 0; // TODO set
    address public constant EDITION = address(0); // TODO set

    bytes32[] leaves;

    bytes32 public root;

    Merkle public m;
    address[] accounts = []; // TODO populate


    function setUpMerkleTree() public {
        // Initialize
        m = new Merkle();

        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(accounts[i]));
        }

        root = m.getRoot(leaves);
    }

    function run() external {
        vm.startBroadcast();

        MerkleDropMinter merkleMinter = MerkleDropMinter(MERKLE_MINTER);
        
        setUpMerkleTree();
        
        

        merkleMinter.setMerkleRootHash(
          EDITION,
          MINT_ID,
          root
        );
        vm.stopBroadcast();
    }
}

// Predict address of new implementation
// Create metadata module using predicted address
// Create new edition implementation with flags and module address
// Deploy mint contract
// Grant mint contract mint permissions on edition