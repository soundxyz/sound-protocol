// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { MintRandomnessLib } from "@core/utils/MintRandomnessLib.sol";
import { TestConfig } from "../../TestConfig.sol";
import "forge-std/Test.sol";

contract MintRandomnessLibTest is TestConfig {
    function test_mintRandomnessWithZeroMaxMintable(uint256 randomness, uint256 totalMinted) public {
        if (randomness == 0) {
            randomness = 1;
        }
        uint256 newRandomness = MintRandomnessLib.nextMintRandomness(randomness, totalMinted, 0);
        assertEq(newRandomness, randomness);
    }

    function test_mintRandomnessUpdateProbability() public view {
        unchecked {
            for (uint256 z; z < 16; ++z) {
                uint256 changesBeforeHalf;
                uint256 changesAfterHalf;
                for (uint256 t; ; ++t) {
                    uint256 randomness = uint256(keccak256(abi.encode(z, t)));
                    uint256 maxMintable = 256;
                    uint256 maxMintableHalf = maxMintable >> 1;
                    for (uint256 i; i < maxMintableHalf; ++i) {
                        uint256 newRandomness = MintRandomnessLib.nextMintRandomness(randomness, i, maxMintable);
                        if (randomness != newRandomness) changesBeforeHalf++;
                        randomness = newRandomness;
                    }
                    for (uint256 i = maxMintableHalf; i < maxMintable; ++i) {
                        uint256 newRandomness = MintRandomnessLib.nextMintRandomness(randomness, i, maxMintable);
                        if (randomness != newRandomness) changesAfterHalf++;
                        randomness = newRandomness;
                    }

                    uint256 deviation;
                    // The area under the PDF before the half point is 3x
                    // the area under the PDF after the half point.
                    if (changesAfterHalf * 3 > changesBeforeHalf) {
                        deviation = changesAfterHalf * 3 - changesBeforeHalf;
                    } else {
                        deviation = changesBeforeHalf - changesAfterHalf * 3;
                    }

                    // If the algorithm is correct, the deviation
                    // has a high chance of converging within the gas limit.
                    // If `deviation / changesAfterHalf < 0.1`, break.
                    if (deviation * 1 ether < changesAfterHalf * 0.1 ether) break;
                }
            }
        }
    }

    function test_mintRandomnessCanUpdateAtLastMint() public {
        unchecked {
            uint256 changes;
            for (uint256 t; t < 8192; ++t) {
                uint256 randomness = t + 1;
                uint256 newRandomness = MintRandomnessLib.nextMintRandomness(randomness, 255, 256);
                if (randomness != newRandomness) changes++;
            }
            assertTrue(changes != 0);
        }
    }
}
