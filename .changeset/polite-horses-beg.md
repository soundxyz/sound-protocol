---
"sound-protocol": minor
---

-   Adds mintedTallies to RangeEditionMinter for maxAllowedPerWallet constraint
-   Removes per-user elligible quantity in Merkle leaves - replacing with maxAllowedPerWallet
-   Removes balanceOf check and maxAllowedPerWallet in MerkleDropMinter
