// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

// MUD imports
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
// for the custom interact system
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { Role, HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, InventoryItem, CharactersByAccount, LocationData, InventoryItemTransfer, InventoryItemTransferData } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { InventoryInteractSystem, inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock custom system to call into the ephemeral interact system
// This fits the expected builder pattern -
//   - create a custom contract that calls into the interact systems, and
//   - then set access config to only allow this custom contract to make calls for thier smart object
contract CustomInventoryInteractSystem is System {
  // Call inventory interact system transferToInventory function
  function callTransferToInventory(
    uint256 inventoryObjectId,
    uint256 toObjectId,
    InventoryItemParams[] memory items
  ) public {
    inventoryInteractSystem.transferToInventory(inventoryObjectId, toObjectId, items);
  }
}

contract EphemeralInteractTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // SSU variables
  uint256 inventoryObjectId;
  uint256 inventoryObjectId2;

  // custom interact system variables
  ResourceId customSystemId;
  CustomInventoryInteractSystem customSystem;

  // Item variables
  bytes32 tenantId;
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
  uint256 constant SMART_OBJECT_ITEM_ID_2 = 5678; // New ID for second SSU

  uint256 item1ObjectId;
  uint256 item2ObjectId;

  function setUp() public virtual override {
    vm.pauseGasMetering();
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
    tenantId = Tenant.get();

    // Setup smart object IDs
    inventoryObjectId = _calculateObjectId(
      EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
      SMART_OBJECT_ITEM_ID,
      true
    );
    inventoryObjectId2 = _calculateObjectId(
      EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
      SMART_OBJECT_ITEM_ID_2,
      true
    );

    // Setup first SSU for inventory (owned by Alice)
    uint256 capacity = 1000;
    world.call(
      smartStorageUnitSystem.toResourceId(),
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorStorageUnit,
        (
          CreateAndAnchorParams(
            inventoryObjectId,
            "SSU",
            EntityRecordParams({
              tenantId: tenantId,
              typeId: EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
              itemId: SMART_OBJECT_ITEM_ID,
              volume: 1000
            }),
            alice,
            LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
          ),
          capacity,
          capacity,
          0 // networkNodeId
        )
      )
    );

    // Setup second SSU for inventory (owned by Bob)
    world.call(
      smartStorageUnitSystem.toResourceId(),
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorStorageUnit,
        (
          CreateAndAnchorParams(
            inventoryObjectId2,
            "SSU2",
            EntityRecordParams({
              tenantId: tenantId,
              typeId: EntityRecord.getTypeId(smartStorageUnitSystem.getSmartStorageUnitClassId()),
              itemId: SMART_OBJECT_ITEM_ID_2,
              volume: 1000
            }),
            bob,
            LocationData({
              solarSystemId: 2, // Different solar system
              x: 2000, // Different coordinates
              y: 2001,
              z: 2002
            })
          ),
          capacity,
          capacity,
          0 // networkNodeId
        )
      )
    );

    // Calculate itemObjectIds
    item1ObjectId = _calculateObjectId(ITEM_TYPE_ID, ITEM1_ID, true); // Singleton item
    item2ObjectId = _calculateObjectId(ITEM_TYPE_ID_NON_SINGLETON, 0, false); // Non-singleton item

    // Set up item records with the correct parameters
    _setupEntityRecord(item1ObjectId, ITEM_TYPE_ID, ITEM1_ID, ITEM_VOLUME);
    _setupEntityRecord(item2ObjectId, ITEM_TYPE_ID_NON_SINGLETON, 0, ITEM_VOLUME);
    vm.stopPrank();

    // Bring Alice's SSU online
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Bring Bob's SSU online
    vm.startPrank(bob, deployer);
    deployableSystem.bringOnline(inventoryObjectId2);
    vm.stopPrank();

    // Mock builder deployment of custom interact system
    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("spaceforalice");
    bytes16 name = bytes16("CustomEphemeralI");
    customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    vm.startPrank(alice);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Deploy and register the mock system
    customSystem = new CustomInventoryInteractSystem();

    // Register the system with the world
    world.registerSystem(customSystemId, customSystem, true);

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_transferToInventory() public {
    // First, add items to primary inventory
    InventoryItemParams[] memory itemParams = new InventoryItemParams[](2);
    itemParams[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });
    itemParams[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 5 });

    vm.startPrank(alice, deployer);
    // Add items to primary inventory
    inventorySystem.depositInventory(inventoryObjectId, itemParams);
    vm.stopPrank();

    // Verify state before transfer
    assertEq(Inventory.lengthItems(inventoryObjectId), 2);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item1ObjectId), 1);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 5);

    // Verify ephemeral inventory is empty
    assertEq(Inventory.lengthItems(inventoryObjectId2), 0);

    // Prepare transfer parameters - transfer some items to target inventory
    InventoryItemParams[] memory transferParams = new InventoryItemParams[](2);
    transferParams[0] = InventoryItemParams({
      smartObjectId: item1ObjectId,
      quantity: 1 // Transfer all of item1
    });
    transferParams[1] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 3 // Transfer part of item2
    });
    vm.pauseGasMetering();
    // Direct call with alice is allowed (SSU owner)
    vm.startPrank(alice);
    inventoryInteractSystem.transferToInventory(inventoryObjectId, inventoryObjectId2, transferParams);
    vm.resumeGasMetering();
    // Verify state after the direct call
    // Check primary inventory - should have less items now
    assertEq(Inventory.lengthItems(inventoryObjectId), 1); // item1 completely gone
    assertEq(InventoryItem.getExists(inventoryObjectId, item1ObjectId), false);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 2); // 5-3=2

    // Check target inventory - should have the transferred items
    assertEq(Inventory.lengthItems(inventoryObjectId2), 2);
    assertEq(InventoryItem.getQuantity(inventoryObjectId2, item1ObjectId), 1);
    assertEq(InventoryItem.getQuantity(inventoryObjectId2, item2ObjectId), 3);

    // Try to add more items via custom system (should fail without access)
    InventoryItemParams[] memory customTransferParams = new InventoryItemParams[](1);
    customTransferParams[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 1 // Transfer 1 more of item2
    });

    // Call should fail due to missing access rights
    vm.expectRevert(
      abi.encodeWithSelector(
        AccessSystem.Access_NotDirectOwnerOrCanTransferToInventory.selector,
        address(customSystem),
        inventoryObjectId
      )
    );
    world.call(
      customSystemId,
      abi.encodeWithSelector(
        CustomInventoryInteractSystem.callTransferToInventory.selector,
        inventoryObjectId,
        inventoryObjectId2,
        customTransferParams
      )
    );

    // Set access for custom system to transfer to inventory
    inventoryInteractSystem.setTransferToInventoryAccess(inventoryObjectId, address(customSystem), true);

    // Now the call should succeed
    world.call(
      customSystemId,
      abi.encodeWithSelector(
        CustomInventoryInteractSystem.callTransferToInventory.selector,
        inventoryObjectId,
        inventoryObjectId2,
        customTransferParams
      )
    );
    vm.stopPrank();

    // Verify state after the custom system call
    // Check primary inventory - should have even fewer items
    assertEq(Inventory.lengthItems(inventoryObjectId), 1);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 1); // 2-1=1

    // Check target inventory - should have more items
    assertEq(Inventory.lengthItems(inventoryObjectId2), 2);
    assertEq(InventoryItem.getQuantity(inventoryObjectId2, item1ObjectId), 1); // unchanged
    assertEq(InventoryItem.getQuantity(inventoryObjectId2, item2ObjectId), 4); // 3+1=4

    // verify item transfer record is being populated (the last item to be transfered will be stored here)
    InventoryItemTransferData memory inventoryItemTransferData = InventoryItemTransfer.get(
      inventoryObjectId,
      item2ObjectId
    );
    assertEq(inventoryItemTransferData.previousOwner, alice);
    assertEq(inventoryItemTransferData.currentOwner, bob);
    assertEq(inventoryItemTransferData.quantity, 1);
    assertEq(inventoryItemTransferData.updatedAt, block.timestamp);
  }

  function test_SetTransferToInventoryAccess() public {
    // Calculate the role ID
    bytes32 roleId = keccak256(abi.encodePacked("TRANSFER_TO_INVENTORY_ROLE", inventoryObjectId));

    // Verify initial state - role should not exist and charlie should not have access
    assertEq(Role.getExists(roleId), false);
    assertEq(HasRole.getIsMember(roleId, charlie), false);

    // Non-owner (bob) attempts to set access should fail
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotDirectOwner.selector, bob, inventoryObjectId));
    inventoryInteractSystem.setTransferToInventoryAccess(inventoryObjectId, charlie, true);

    // Owner (alice) can set access
    vm.prank(alice);
    inventoryInteractSystem.setTransferToInventoryAccess(inventoryObjectId, charlie, true);

    // Verify state is updated - role should exist and charlie should have access
    assertEq(Role.getExists(roleId), true);
    assertEq(HasRole.getIsMember(roleId, charlie), true);

    // Owner can also revoke access
    vm.prank(alice);
    inventoryInteractSystem.setTransferToInventoryAccess(inventoryObjectId, charlie, false);

    // Verify state is updated - role should still exist but charlie should not have access
    assertEq(Role.getExists(roleId), true);
    assertEq(HasRole.getIsMember(roleId, charlie), false);
  }

  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 typeId, uint256 itemId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(tenantId, typeId)));

    if (itemId != 0) {
      // For singleton items
      EntityRecord.set(entityId, true, tenantId, typeId, itemId, volume);

      if (!EntityRecord.getExists(classId)) {
        EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
      }
    } else {
      // For non-singleton items
      EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
    }

    if (!Entity.getExists(classId)) {
      entitySystem.registerClass(classId, new ResourceId[](0));
    }
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
