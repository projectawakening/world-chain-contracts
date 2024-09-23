# @eveworld/world
## 0.0.16
- all @latticexyz packages upgraded to version 2.2.7
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
