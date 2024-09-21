# @eveworld/standard-contracts
## 0.0.2
**Update to _isTrustedByTarget Function:**
The `_isTrustedByTarget` function was updated to make an external call to eveworld__isTrustedForwarder 

Before: The function was using ERC2771Context.isTrustedForwarder in the root namespace

After: It now calls IForwarderSystem.eveworld__isTrustedForwarder, reflecting a migration to the eveworld namespace