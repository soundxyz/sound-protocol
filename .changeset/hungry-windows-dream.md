---
"sound-protocol": minor
---

- Removes `onlyValidRangeTimes` (no longer needed because we only do the check in one place)
- Adds public virtual BaseMinter.setTimeRange
- Adds internal virtual BaseMinter._beforeSetTimeRange that can be optionally implemented by minters
- Fixes related bug in FixedPricePermissionedSaleMinter.createEditionMint