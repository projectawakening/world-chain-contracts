# @eveworld/world
## 0.0.17
- Enforce one-to-one mapping for smart character address to id - includes a new error - `SmartCharacter_AlreadyCreated(address characterAddress, uint256 characterId);`
- Added a reverse lookup table called `CharctersByAddressTable` - key characterAddress, returns characterId - used to enforce that any Ephemeral Inventory Owner that get sent items is in-fact a created character (so items don't get sent to blackhole addresses)
- Created a new simpler struct `TransferItem`, to make InventoryInteract usability easier
- `TransferItem` only includes: the `inventoryItemId`, `owner`, and `quantity` since the other fieilds are already in `EntityRecord`
- Subsequently use EntityRecord data to create the full InventoryItem object to pass into the Inventory and EphemeralInventory modules
- Implemented a `InventoryInteract.setApprovedAccessList` - this allows the Inventory owner to APPROVE others access to the InventoryInteract transfer functions via `_msgSender()` checking (including other Systems or EOAs)
- Implemented `setAllTransferAccess`, `setEphemeralToInventoryTransferAccess`, and `setInventoryToEphemeralTransferAccess` - these allow the Inventory Owner `onlyOwner` to toggle the access control on/off for the InventoryInteract.transfer functions.
- Enforcement modifier `onlyOwnerOrSystemApproved` for `InventoryInteract.inventoryToEphemeralTransfer` 
- When`onlyOwnerOrSystemApproved` is active, the Inventory Owner can still call directly to the function or through other System calls ( because `_initialMsgSender `is checked), however, other EOAs can only call by being APPROVED and calling direct OR they can cal via an APPROVED System (`_msgSender` is checked). This gives the Inventory Owner freedom to call how they wish but protect the `InventoryInteract.inventoryToEphemeralTransfer` function from 3rd party calls (unless APPROVED or calling via an APPROVED System).
- Enforcement rmodifier `onlySystemApproved` for `InventoryInteract.ephemeralToInventoryTransfer`
-  When `onlySystemApproved` is active, the Ephemeral Inventory Owner can no longer call directly unless they are APPROVED or call via and APPROVED System. This give the Object Inventory Owner the ability to control how Ephemeral Owners interact with their Object.

## 0.0.16
- all @latticexyz packages upgraded to version 2.2.8
- implemented intialMsgSender() context capture as a customWorld contract named WorldWithEntryContext.sol
- adding the term System to the end of all systems
- mud.config updates for table declarations and custom world
- removed tableId parameters from Table calls
- adjusted System-to-System APPROVED access logic to be configurable per System
- update the InventoryAccess.s.sol script to accommodate access logic changes
- updating unit tests to use MudTest.sol instead of the basic forge Test.sol

## 0.0.15
- changed kill mail implementation: killer and victim values from characterIds to evm addressess
- bugfix for gate link distance calculation formula

## 0.0.14
- renaming `smartStorageUnitId` to  `smartObjectId` for inventory for consistency 
- consistant naming for `smartObjectId` across systems and MUD Table

## 0.0.13
- Refactored SmartGateLinkTable structure to query by sourceGate as single key
- Implementation of default logic for smart turrets and smart gates
- normalized naming conventions (Breaking change in terms of abi)
  - renamed `fuelConsumptionPerMinute` to `fuelConsumptionIntervalInSeconds`
  - renamed `smartObjectId` to `smartStorageUnitId` for the function `createAndAnchorSmartStorageUnit`
- included turretOwnerCharacterId as a additional parameter for `inProximity` and `aggression`

## 0.0.12
- Including Gate and Kill Mail in mud.config to generate abis 
- Adding scripts for end-to-end tests 

## 0.0.11

### Patch Changes

- smart turret feature implementation
- update smart character creation (Breaking Change in interface)
  - added corpId to `createCharacter` function
  - added function to update corpId
  
## 0.0.10

### Patch Changes

- Fix incorrect import in world feature PostDeploy script.
  Update nx

## 0.0.9

### Patch Changes

- Fixes the fuel consumption formula

## 0.0.8

### Patch Changes

- Bug fix: inventory interact inventoryToEphemeralTransferWithParam with parameter

## 0.0.7

### Patch Changes

- Playtest release v0.0.7
- Updated dependencies
  - @eveworld/smart-object-framework@0.0.7
  - @eveworld/common-constants@0.0.7
