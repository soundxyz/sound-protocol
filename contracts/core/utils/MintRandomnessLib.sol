// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/*
                 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▒███████████████████████████████████████████████████████████
               ▒███████████████████████████████████████████████████████████
 ▒▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓               ▒▒▒▒▒▒▒▒▒▒▒▒▒██████████████████████████████
 █████████████████████████████▓                            ▒█████████████████████████████
 █████████████████████████████▓                             ▒████████████████████████████
 █████████████████████████████████████████████████████████▓
 ███████████████████████████████████████████████████████████
 ███████████████████████████████████████████████████████████▒
                              ███████████████████████████████████████████████████████████▒
                              ▓██████████████████████████████████████████████████████████▒
                               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████████████████████▒
 █████████████████████████████                             ▒█████████████████████████████▒
 ██████████████████████████████                            ▒█████████████████████████████▒
 ██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒              ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒███████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▓██████████████████████████████████████████████████████████▒
               ▓██████████████████████████████████████████████████████████
*/

library MintRandomnessLib {
    /**
     * @dev Returns the next mint randomness.
     * @param randomness  The current mint randomness.
     * @param totalMinted The total number of tokens minted.
     * @param quantity    The number of tokens to mint.
     * @param maxMintable The maximum number of tokens that can be minted.
     * @return newRandomness The next mint randomness.
     */
    function nextMintRandomness(
        uint256 randomness,
        uint256 totalMinted,
        uint256 quantity,
        uint256 maxMintable
    ) internal view returns (uint256 newRandomness) {
        assembly {
            newRandomness := randomness
            // If neither `maxMintable` nor `quantity` is zero.
            if mul(maxMintable, quantity) {
                let end := add(totalMinted, quantity)
                // prettier-ignore
                for {} 1 {} {
                    // Pick any of the last 256 blocks pseudorandomly for the blockhash.
                    mstore(0x00, blockhash(sub(number(), add(1, and(0xff, randomness)))))
                    // After the merge, if [EIP-4399](https://eips.ethereum.org/EIPS/eip-4399)
                    // is implemented, the `difficulty()` will be determined by the beacon chain.
                    // We also need to xor with the `totalMinted` to prevent the randomness
                    // from being stucked.
                    mstore(0x20, xor(xor(randomness, difficulty()), totalMinted))

                    let r := keccak256(0x00, 0x40)

                    switch randomness
                    case 0 {
                        // If `randomness` is uninitialized,
                        // initialize all bits pseudorandomly.
                        newRandomness := r
                    }
                    default {
                        // Decay the chance to update as more are minted.
                        if gt(add(mod(r, maxMintable), 1), totalMinted) {
                            // If `randomness` has already been initialized,
                            // each update can only contribute 1 bit of pseudorandomness.
                            mstore(0x00, or(shl(1, randomness), shr(255, r)))
                            newRandomness := keccak256(0x00, 0x20)
                        }
                    }
                    randomness := newRandomness
                    totalMinted := add(totalMinted, 1)
                    // prettier-ignore
                    if eq(totalMinted, end) { break }
                }
            }
        }
    }
}
