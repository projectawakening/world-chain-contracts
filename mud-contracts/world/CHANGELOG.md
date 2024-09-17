# @eveworld/world
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
