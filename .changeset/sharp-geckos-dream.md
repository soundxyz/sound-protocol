---
"sound-protocol": patch
---

Addresses feedback that was missed as a result of merging #51 too early

- Removing .env that was mistakingly committed
- Moving startTime and endTime check in MintControllerBase to modifier

RangeEditionMinter changes:
- Move validation before storage writes for createEditionMint
- Rename requestedQuantity to quantity
- Removing unnecessary closingTime checks in RangEditionMinter
- Added tests that existed in FixedSalePublicMinter (deleted) to RangeEditionMinter
