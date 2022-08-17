---
"sound-protocol": minor
---

- Removes MintControllerBase.BaseData.controller & all related events & errors
- Replaces onlyEditionMintController with onlyEditionOwnerOrAdmin
- Removes MintControllerBase.setEditionMintController & deleteEditionMintController functions on child minters
- Changes MintControllerSet to MintConfigCreated, indexes the creator's address & adds startTime & endTime
