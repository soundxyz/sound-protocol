---
"sound-protocol": minor
---

- Removes MinterBase.BaseData.controller & all related events & errors
- Replaces onlyEditionMintController with onlyEditionOwnerOrAdmin
- Removes MinterBase.setEditionMintController & deleteEditionMintController functions on child minters
- Changes MintControllerSet to MintConfigCreated, indexes the creator's address & adds startTime & endTime
