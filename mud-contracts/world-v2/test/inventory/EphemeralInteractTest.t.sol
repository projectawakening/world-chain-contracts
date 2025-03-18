// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { 
  GlobalDeployableState, 
  Inventory, 
  Tenant, 
  EntityRecord, 
  DeployableState, 
  DeployableStateData, 
  InventoryItemData, 
  InventoryItem,
  InventoryByItem,
  OwnershipByObject,
  EphemeralInvCapacity,
  CharactersByAccount,
  LocationData,
  ObjectByEphemeral,
  ObjectByEphemeralData,
  EphemeralInventory,
  EphemeralInvItem,
  EphemeralInvItemData
} from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { EphemeralInteractSystem, ephemeralInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

contract EphemeralInteractTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 inventoryObjectId;

  bytes32 tenantId;

  // Item variables
  uint256 constant ITEM1_ID = 4235;
  uint256 constant ITEM_TYPE_ID = 1000;
  uint256 constant ITEM_TYPE_ID_NON_SINGLETON = 1001; // Non-singleton item type
  uint256 constant ITEM_VOLUME = 100;
  uint256 constant TRANSFER_ITEM_TYPE_ID = 9091;

  // Test addresses
  address deployer;
  address alice;
  address bob;
  address charlie;

  uint256 constant SMART_OBJECT_ITEM_ID = 1234;
  
  uint256 item1ObjectId;
  uint256 item2ObjectId;

  function setUp() public virtual override {
    super.setUp();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);
    
    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));
    bob = vm.addr(vm.deriveKey(mnemonic, 3));
    charlie = vm.addr(vm.deriveKey(mnemonic, 4));

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice and bob
    CharactersByAccount.set(alice, 1);
    CharactersByAccount.set(bob, 2);
    
    // Setup tenant
    tenantId = keccak256(abi.encodePacked("TEST"));
    
    // Setup smart object IDs
    inventoryObjectId = _calculateObjectId(SMART_OBJECT_ITEM_ID, EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()), true);

    // Make sure deploy system is active
    GlobalDeployableState.setIsPaused(true); // Use true for "active" (counterintuitive, but matches the contract)

    // Setup deployable state for inventory
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      inventoryObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
        itemId: SMART_OBJECT_ITEM_ID,
        volume: 1000
      }),
      alice,
      1,
      10,
      100000,
      LocationData({
        solarSystemId: 1,
        x: 1000,
        y: 1001,
        z: 1002
      })
    ));

    // Set capacity for the inventory
    uint256 capacity = 1000;
    inventorySystem.setCapacity(inventoryObjectId, capacity);

    // Calculate itemObjectIds
    item1ObjectId = _calculateObjectId(ITEM1_ID, ITEM_TYPE_ID, true); // Singleton item
    item2ObjectId = _calculateObjectId(0, ITEM_TYPE_ID_NON_SINGLETON, false); // Non-singleton item
    
    // Set up item records with the correct parameters
    _setupEntityRecord(item1ObjectId, ITEM1_ID, ITEM_TYPE_ID, ITEM_VOLUME);
    _setupEntityRecord(item2ObjectId, 0, ITEM_TYPE_ID_NON_SINGLETON, ITEM_VOLUME);

    // Set ephemeral capacity for the smart object
    uint256 ephemeralCapacity = 1000;
    inventorySystem.setEphemeralCapacity(inventoryObjectId, ephemeralCapacity);
    
    vm.stopPrank();
  }


  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    
    if (itemId != 0) { // For singleton items
      EntityRecord.set(entityId, true, tenantId, itemId, typeId, volume);

      if (!EntityRecord.getExists(classId)) {
        EntityRecord.set(classId, true, bytes32(0), 0, typeId, volume);
      }
    } else { // For non-singleton items
      EntityRecord.set(classId, true, bytes32(0), 0, typeId, volume);
    }
    
    if (!Entity.getExists(classId)) {
      entitySystem.registerClass(classId, new ResourceId[](0));
    }
  }

  function _calculateObjectId(uint256 itemId, uint256 typeId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}