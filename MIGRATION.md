# V2 Migration Guide

## High Level Overview

- Stricter validation ensures data integrity and on-chain errors
- Simplified ownership model with dedicated ownership systems
- Enhanced inventory management with version-based synchronization
- Improved access control with granular permissions
- Tenant-based entity record system for better data organization

## New Features

- Introduced dedicated `OwnershipSystem` and `InventoryOwnershipSystem` for centralized ownership management
- Tenant-based entity records with strict validation
- Version-based inventory synchronization for both regular and ephemeral inventories
- Granular access control with system-to-system call permissions
- Removed ERC721 token standards from deployables and characters
- All transfer types supported: inventory to ephemeral, ephemeral to inventory, inventory to inventory, and ephemeral to ephemeral

## Flow Changes

### Ownership Management

- Ownership is now managed through dedicated systems instead of ERC721 tokens
- Direct ownership tracking through `OwnershipByObject` table
- Inventory ownership is synchronized with version checks
- Smart objects can have either direct ownership or inventory-based ownership

### Inventory Management

- Version-based synchronization between ephemeral and main inventories
- Automatic version checks during deposit and withdrawal operations
- Reset of ephemeral inventory on version mismatch
- Strict validation of inventory operations through access control

### Entity Records

- Tenant-based entity record system for better data organization
- Strict validation of entity records during creation
- Enhanced metadata management with granular access control
- Improved entity relationship tracking

## Old Usage vs New Usage

### Table Changes

```solidity
// Old
StaticDataTable -> Removed
ItemTransferOffchainTable -> EphemeralItemTransfer

// New
OwnershipByObject (new)
InventoryByItem (new)
EntityRecord (enhanced)
```

### Function Changes

```solidity
// Old - Character Creation
createCharacter(address characterAddress, uint256 characterId)

// New - Character Creation
createCharacter(uint256 smartObjectId, address owner, uint256 tribeId, EntityRecordParams memory entityRecordParams)

// Old - Inventory Transfer
transferItem(uint256 inventoryItemId, address owner)

// New - Inventory Transfer
transferItem(InventoryItemParams memory params)
```

## Known Issues

- Entity record deletion can lead to orphaned data - currently prohibited
- Version mismatches between ephemeral and main inventories require manual synchronization

## Error Messages

```solidity
Ownership_InvalidSingleton(uint256 smartObjectId)
Ownership_InvalidAccount(address account)
Ownership_InvalidOwner(uint256 smartObjectId, address invalidOwner)
Ownership_NonexistentObject(uint256 smartObjectId)
Ownership_AlreadyOwned(uint256 smartObjectId, address currentOwner)
```

## Migration Steps

1. Update all ERC721 token references to use the new ownership system
2. Configure tenant IDs for entity records
3. Update inventory transfer calls to use the new parameter structures
4. Implement version synchronization for inventory operations
5. Update access control configurations for system-to-system calls
6. Remove any static data references and migrate to entity records

## Access Control Changes

- System-to-system calls now require explicit permissions
- Role-based access control for inventory operations
- Granular access control for entity record modifications
- Owner-specific permissions for metadata updates

## Best Practices

1. Always check inventory versions before operations
2. Use the appropriate ownership system functions for transfers
3. Implement proper error handling for version mismatches
4. Follow the tenant-based entity record pattern
5. Use the provided access control mechanisms for system interactions

## Technical Details

- Namespace changed from `eveworld` to `evefrontier`
- All systems now use `smartObjectId` consistently
- Entity records include tenant validation
- Version tracking implemented at inventory level
- System-to-system calls tracked through `CallAccess` table
