// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, DeployableState, DeployableStateData, InventoryItemData, InventoryItem, InventoryByItem, OwnershipByObject, EphemeralInvCapacity, CharactersByAccount, LocationData, EphemeralInventory, EphemeralInvItem, InventoryByEphemeral } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryOwnershipSystemLib.sol";

import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock system to properly test system-to-system calls
contract MockInventoryOwnershipInteractSystem is System {
  function callAssignOwnerToInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) public {
    inventoryOwnershipSystem.assignItemToInventory(inventoryObjectId, itemObjectId, quantity);
  }

  function callRemoveOwnerFromInventory(uint256 inventoryObjectId, uint256 itemObjectId, uint256 quantity) public {
    inventoryOwnershipSystem.removeItemFromInventory(inventoryObjectId, itemObjectId, quantity);
  }
}

contract InventoryOwnershipTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 smartObjectId;
  bytes32 tenantId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;

  // Item variables - simplified to just one singleton and one non-singleton type
  uint256 constant SINGLETON_ITEM_ID = 4235;
  uint256 constant SINGLETON_ITEM_TYPE_ID = 1000;
  uint256 constant NON_SINGLETON_ITEM_TYPE_ID = 1001;
  uint256 constant ITEM_VOLUME = 100;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  // Item object IDs
  uint256 singletonItemObjectId;
  uint256 nonSingletonItemObjectId;

  // Mock system address
  MockInventoryOwnershipInteractSystem mockSystem;
  ResourceId mockSystemId;

  function setUp() public virtual override {
    vm.pauseGasMetering();
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

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice and bob
    CharactersByAccount.set(alice, 1);
    CharactersByAccount.set(bob, 2);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

    // Register class and setup smart object state
    uint256 inventoryObjectClassId = _calculateObjectId(SMART_OBJECT_TYPE_ID, 0, false);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockInvOwnership");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockInventoryOwnershipInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](9);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = inventorySystem.toResourceId();
    systemIds[5] = ephemeralInventorySystem.toResourceId();
    systemIds[6] = ownershipSystem.toResourceId();
    systemIds[7] = inventoryOwnershipSystem.toResourceId();
    systemIds[8] = mockSystemId;

    entitySystem.registerClass(inventoryObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(inventoryObjectClassId, smartObjectId, alice);

    // Setup deployable state for inventory
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      ),
      0 // networkNodeId
    );

    // Set capacity for inventory
    uint256 capacity = 1000;
    inventorySystem.setCapacity(smartObjectId, capacity);
    // Set ephemeral capacity to same value
    inventorySystem.setCapacity(smartObjectId, capacity);

    // Calculate itemObjectIds
    singletonItemObjectId = _calculateObjectId(SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID, true);
    nonSingletonItemObjectId = _calculateObjectId(NON_SINGLETON_ITEM_TYPE_ID, 0, false);

    // Set up item records with the correct parameters
    _setupEntityRecord(singletonItemObjectId, SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID, ITEM_VOLUME);
    _setupEntityRecord(nonSingletonItemObjectId, NON_SINGLETON_ITEM_TYPE_ID, 0, ITEM_VOLUME);

    // Configure access control to allow the mock system to call ownership system
    ResourceId ownershipSystemId = ownershipSystem.toResourceId();
    bytes4[4] memory ownershipFunctionSelectors = [
      OwnershipSystem.assignOwner.selector,
      OwnershipSystem.removeOwner.selector,
      InventoryOwnershipSystem.assignItemToInventory.selector,
      InventoryOwnershipSystem.removeItemFromInventory.selector
    ];

    for (uint i = 0; i < ownershipFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystemId, ownershipFunctionSelectors[i], address(mockSystem), true);
    }
    vm.stopPrank();

    // Bring deployable online
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_assignItemToInventory() public {
    // Test assigning item ownership to an inventory using the smartObjectId and singletonItemObjectId/nonSingletonItemObjectId from setUp
    vm.pauseGasMetering();
    // Verify initial state - should have no inventory items initially
    assertEq(
      InventoryItem.getQuantity(smartObjectId, singletonItemObjectId),
      0,
      "Should have no singleton items initially"
    );
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      0,
      "Should have no non-singleton items initially"
    );
    assertEq(InventoryByItem.get(singletonItemObjectId), 0, "Singleton item should not be in any inventory");

    // Test revert case 1: Non-existent item record
    uint256 nonExistentItemId = 9999999;
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_NonexistentItemRecord.selector,
        nonExistentItemId
      )
    );
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonExistentItemId, 1);

    // Test revert case 2: Non-existent inventory object
    uint256 nonExistentInventoryId = 8888888;
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_NonexistentObject.selector,
        nonExistentInventoryId
      )
    );
    inventoryOwnershipSystem.assignItemToInventory(nonExistentInventoryId, singletonItemObjectId, 1);

    // Test revert case 3: Invalid quantity for singleton item (should be exactly 1)
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InvalidQuantity.selector,
        singletonItemObjectId,
        2,
        1
      )
    );
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, singletonItemObjectId, 2);

    // Test revert case 4: Zero quantity for non-singleton item
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_ZeroQuantity.selector,
        nonSingletonItemObjectId
      )
    );
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, 0);

    // Test successful case 1: Add singleton item to inventory
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, singletonItemObjectId, 1);

    // Verify state changes for singleton item
    assertEq(
      InventoryItem.getQuantity(smartObjectId, singletonItemObjectId),
      1,
      "Should have 1 singleton item after assigning"
    );
    assertEq(InventoryByItem.get(singletonItemObjectId), smartObjectId, "Singleton item should be in the inventory");
    // Verify item version matches inventory version
    assertEq(
      InventoryItem.getVersion(smartObjectId, singletonItemObjectId),
      Inventory.getVersion(smartObjectId),
      "Item version should match inventory version"
    );
    assertEq(
      ownershipSystem.owner(singletonItemObjectId),
      alice,
      "Singleton item should be owned by Alice after adding to Alice's inventory"
    );

    // Test successful case 2: Add non-singleton item to inventory
    uint256 nonSingletonQuantity = 5;
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, nonSingletonQuantity);

    // Verify state changes for non-singleton item
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      nonSingletonQuantity,
      "Should have correct quantity of non-singleton items"
    );
    // Verify item version matches inventory version
    assertEq(
      InventoryItem.getVersion(smartObjectId, nonSingletonItemObjectId),
      Inventory.getVersion(smartObjectId),
      "Non-singleton item version should match inventory version"
    );

    // Test adding more of the non-singleton item (should add to existing quantity)
    uint256 additionalQuantity = 3;
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, additionalQuantity);

    // Verify incremented quantity
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      nonSingletonQuantity + additionalQuantity,
      "Should have accumulated quantity of non-singleton items"
    );

    // Test assigning to inventory after the inventory version has been bumped
    // Let's first clear the inventory to have a clean state
    // We use the existing nonSingletonItemObjectId that was already set up
    uint256 currentQuantity = InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId);
    if (currentQuantity > 0) {
      inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, nonSingletonItemObjectId, currentQuantity);
    }

    // Add items to the inventory
    uint256 testQuantityBefore = 5;
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, testQuantityBefore);

    // Verify initial quantity
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      testQuantityBefore,
      "Initial quantity should be set correctly"
    );

    // Now bump the inventory version
    vm.startPrank(deployer);
    uint256 newVersion = Inventory.getVersion(smartObjectId) + 1;
    Inventory.setVersion(smartObjectId, newVersion);
    vm.stopPrank();

    // Add items after version bump - this should REPLACE the quantity instead of adding to it
    uint256 testQuantityAfter = 3;
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, testQuantityAfter);

    // Verify the quantity is replaced, not added
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      testQuantityAfter,
      "Quantity should be replaced after version bump, not added to previous quantity"
    );

    // Setup ephemeral inventory for testing
    // Create the ephemeral inventory connection to our smart object with bob as the owner
    vm.startPrank(deployer);
    EphemeralInventory.setVersion(smartObjectId, bob, Inventory.getVersion(smartObjectId)); // Match the primary inventory version
    uint256 ephemeralSmartObjectId = uint256(keccak256(abi.encodePacked(smartObjectId, bob)));
    InventoryByEphemeral.set(ephemeralSmartObjectId, true, smartObjectId, bob);

    // Test successful case 3: Add singleton item to ephemeral inventory
    uint256 ephemeralSingletonItemId = _calculateObjectId(SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID + 1, true);

    // Setup entity record for the new singleton item
    _setupEntityRecord(ephemeralSingletonItemId, SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID + 1, ITEM_VOLUME);
    vm.stopPrank();

    // Add it to the ephemeral inventory
    inventoryOwnershipSystem.assignItemToInventory(ephemeralSmartObjectId, ephemeralSingletonItemId, 1);

    // Verify state changes for singleton item in ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, ephemeralSingletonItemId),
      1,
      "Should have 1 singleton item in ephemeral inventory"
    );
    assertEq(
      InventoryByItem.get(ephemeralSingletonItemId),
      ephemeralSmartObjectId,
      "Singleton item should be in the ephemeral inventory"
    );
    // Verify ephemeral item version matches ephemeral inventory version
    assertEq(
      EphemeralInvItem.getVersion(smartObjectId, bob, ephemeralSingletonItemId),
      EphemeralInventory.getVersion(smartObjectId, bob),
      "Ephemeral item version should match ephemeral inventory version"
    );
    assertEq(
      ownershipSystem.owner(ephemeralSingletonItemId),
      bob,
      "Ephemeral singleton item should be owned by Bob after adding to Bob's ephemeral inventory"
    );

    // Test successful case 4: Add non-singleton item to ephemeral inventory
    uint256 ephemeralNonSingletonQuantity = 10;

    // Add it to the ephemeral inventory
    inventoryOwnershipSystem.assignItemToInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      ephemeralNonSingletonQuantity
    );

    // Verify state changes for non-singleton item in ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      ephemeralNonSingletonQuantity,
      "Should have correct quantity in ephemeral inventory"
    );

    // Test adding more of the non-singleton item to ephemeral inventory
    uint256 additionalEphemeralQuantity = 7;
    inventoryOwnershipSystem.assignItemToInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      additionalEphemeralQuantity
    );

    // Verify incremented quantity in ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      ephemeralNonSingletonQuantity + additionalEphemeralQuantity,
      "Should have accumulated quantity in ephemeral inventory"
    );

    // Test version bumping with ephemeral inventory
    // First clear out existing items for clean test
    currentQuantity = EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId);
    if (currentQuantity > 0) {
      inventoryOwnershipSystem.removeItemFromInventory(
        ephemeralSmartObjectId,
        nonSingletonItemObjectId,
        currentQuantity
      );
    }

    // Add items to ephemeral inventory
    inventoryOwnershipSystem.assignItemToInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      testQuantityBefore
    );

    // Verify initial quantity
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      testQuantityBefore,
      "Initial ephemeral quantity should be set correctly"
    );

    // Bump the ephemeral inventory version
    vm.startPrank(deployer);
    uint256 newEphemeralVersion = EphemeralInventory.getVersion(smartObjectId, bob) + 1;
    EphemeralInventory.setVersion(smartObjectId, bob, newEphemeralVersion);
    vm.stopPrank();

    // Add items after version bump - should REPLACE the quantity
    inventoryOwnershipSystem.assignItemToInventory(ephemeralSmartObjectId, nonSingletonItemObjectId, testQuantityAfter);

    // Verify the quantity is replaced, not added
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      testQuantityAfter,
      "Ephemeral quantity should be replaced after version bump, not added to previous quantity"
    );

    // Verify that the item's version got updated to match the ephemeral inventory version
    assertEq(
      EphemeralInvItem.getVersion(smartObjectId, bob, nonSingletonItemObjectId),
      newEphemeralVersion,
      "Ephemeral item version should be updated to match ephemeral inventory version"
    );

    // Verify inventory ownership is cleared after inventory version bump
    assertEq(
      ownershipSystem.owner(singletonItemObjectId),
      address(0),
      "Singleton item should have no owner after inventory version bump"
    );
    // Verify ephemeral ownership is cleared after ephemeral inventory version bump
    assertEq(
      ownershipSystem.owner(ephemeralSingletonItemId),
      address(0),
      "Ephemeral singleton item should have no owner after inventory version bump"
    );
    vm.resumeGasMetering();
  }

  function test_removeFromInventory() public {
    vm.pauseGasMetering();
    // First, setup inventory with items so we can test removing them

    // Add singleton item to regular inventory
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, singletonItemObjectId, 1);

    // Add non-singleton items to regular inventory
    uint256 nonSingletonQuantity = 10;
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, nonSingletonItemObjectId, nonSingletonQuantity);

    // Setup ephemeral inventory for testing
    vm.startPrank(deployer);
    EphemeralInventory.setVersion(smartObjectId, bob, Inventory.getVersion(smartObjectId)); // Match the primary inventory version
    uint256 ephemeralSmartObjectId = uint256(keccak256(abi.encodePacked(smartObjectId, bob)));
    InventoryByEphemeral.set(ephemeralSmartObjectId, true, smartObjectId, bob);

    // Create a new singleton item for ephemeral inventory
    uint256 ephemeralSingletonItemId = _calculateObjectId(SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID + 1, true);
    _setupEntityRecord(ephemeralSingletonItemId, SINGLETON_ITEM_TYPE_ID, SINGLETON_ITEM_ID + 1, ITEM_VOLUME);
    vm.stopPrank();

    // Add the singleton item to ephemeral inventory
    inventoryOwnershipSystem.assignItemToInventory(ephemeralSmartObjectId, ephemeralSingletonItemId, 1);

    // Add non-singleton items to ephemeral inventory
    uint256 ephemeralNonSingletonQuantity = 7;
    inventoryOwnershipSystem.assignItemToInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      ephemeralNonSingletonQuantity
    );

    // Verify initial state for regular inventory
    assertEq(
      InventoryItem.getQuantity(smartObjectId, singletonItemObjectId),
      1,
      "Should have 1 singleton item initially"
    );
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      nonSingletonQuantity,
      "Should have correct quantity of non-singleton items initially"
    );
    assertEq(InventoryByItem.get(singletonItemObjectId), smartObjectId, "Singleton item should be in the inventory");
    assertEq(ownershipSystem.owner(singletonItemObjectId), alice, "Singleton item should be owned by Alice");

    // Verify initial state for ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, ephemeralSingletonItemId),
      1,
      "Should have 1 ephemeral singleton item initially"
    );
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      ephemeralNonSingletonQuantity,
      "Should have correct quantity of non-singleton items in ephemeral inventory"
    );
    assertEq(
      InventoryByItem.get(ephemeralSingletonItemId),
      ephemeralSmartObjectId,
      "Ephemeral singleton item should be in the ephemeral inventory"
    );
    assertEq(ownershipSystem.owner(ephemeralSingletonItemId), bob, "Ephemeral singleton item should be owned by Bob");

    // Test revert cases

    // Test revert case 1: Non-existent inventory object
    uint256 nonExistentInventoryId = 8888888;
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InvalidInventory.selector,
        singletonItemObjectId,
        nonExistentInventoryId
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(nonExistentInventoryId, singletonItemObjectId, 1);

    // Test revert case 2: Invalid quantity for singleton item (should be exactly 1)
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InvalidQuantity.selector,
        singletonItemObjectId,
        2,
        1
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, singletonItemObjectId, 2);

    // Test revert case 3: Zero quantity for non-singleton item
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_ZeroQuantity.selector,
        nonSingletonItemObjectId
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, nonSingletonItemObjectId, 0);

    // Test revert case 4: Not enough items in inventory
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InsufficientQuantity.selector,
        smartObjectId,
        nonSingletonItemObjectId,
        nonSingletonQuantity + 1,
        nonSingletonQuantity
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, nonSingletonItemObjectId, nonSingletonQuantity + 1);

    // Test successful case 1: Remove a singleton item from regular inventory
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, singletonItemObjectId, 1);

    // Verify state changes for singleton item
    assertEq(
      InventoryItem.getQuantity(smartObjectId, singletonItemObjectId),
      0,
      "Singleton item should be removed from inventory"
    );
    assertEq(InventoryByItem.get(singletonItemObjectId), 0, "InventoryByItem should be cleared for singleton item");
    assertEq(ownershipSystem.owner(singletonItemObjectId), address(0), "Singleton item should no longer have an owner");

    // Test successful case 2: Partial remove of non-singleton item from regular inventory
    uint256 partialQuantity = 3;
    uint256 remainingQuantity = nonSingletonQuantity - partialQuantity;
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, nonSingletonItemObjectId, partialQuantity);

    // Verify partial removal of non-singleton item
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      remainingQuantity,
      "Non-singleton item quantity should be reduced"
    );

    // Test successful case 3: Complete remove of remaining non-singleton items
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, nonSingletonItemObjectId, remainingQuantity);

    // Verify complete removal of non-singleton item
    assertEq(
      InventoryItem.getQuantity(smartObjectId, nonSingletonItemObjectId),
      0,
      "Non-singleton item should be completely removed from inventory"
    );

    // Test successful case 4: Remove a singleton item from ephemeral inventory
    inventoryOwnershipSystem.removeItemFromInventory(ephemeralSmartObjectId, ephemeralSingletonItemId, 1);

    // Verify state changes for ephemeral singleton item
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, ephemeralSingletonItemId),
      0,
      "Ephemeral singleton item should be removed from ephemeral inventory"
    );
    assertEq(
      InventoryByItem.get(ephemeralSingletonItemId),
      0,
      "InventoryByItem should be cleared for ephemeral singleton item"
    );
    assertEq(
      ownershipSystem.owner(ephemeralSingletonItemId),
      address(0),
      "Ephemeral singleton item should no longer have an owner"
    );

    // Test successful case 5: Partial remove of non-singleton item from ephemeral inventory
    uint256 ephemeralPartialQuantity = 2;
    uint256 ephemeralRemainingQuantity = ephemeralNonSingletonQuantity - ephemeralPartialQuantity;
    inventoryOwnershipSystem.removeItemFromInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      ephemeralPartialQuantity
    );

    // Verify partial removal of non-singleton item from ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      ephemeralRemainingQuantity,
      "Ephemeral non-singleton item quantity should be reduced"
    );

    // Test successful case 6: Complete remove of remaining non-singleton items from ephemeral inventory
    inventoryOwnershipSystem.removeItemFromInventory(
      ephemeralSmartObjectId,
      nonSingletonItemObjectId,
      ephemeralRemainingQuantity
    );

    // Verify complete removal of non-singleton item from ephemeral inventory
    assertEq(
      EphemeralInvItem.getQuantity(smartObjectId, bob, nonSingletonItemObjectId),
      0,
      "Non-singleton item should be completely removed from ephemeral inventory"
    );

    // Test version mismatch behavior with a new item

    // Add an item to test with
    inventoryOwnershipSystem.assignItemToInventory(smartObjectId, singletonItemObjectId, 1);

    // Bump the inventory version
    vm.startPrank(deployer);
    uint256 newVersion = Inventory.getVersion(smartObjectId) + 1;
    Inventory.setVersion(smartObjectId, newVersion);
    vm.stopPrank();

    // Try to remove - should fail because the item version doesn't match inventory version
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InsufficientQuantity.selector,
        smartObjectId,
        singletonItemObjectId,
        1,
        0
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(smartObjectId, singletonItemObjectId, 1);
    assertEq(
      ownershipSystem.owner(singletonItemObjectId),
      address(0),
      "Singleton item should have no owner after version bump"
    );

    // Add an item to ephermal inventory test with
    inventoryOwnershipSystem.assignItemToInventory(ephemeralSmartObjectId, ephemeralSingletonItemId, 1);

    // bump the ephemeral inventory version
    vm.startPrank(deployer);
    uint256 newEphemeralVersion = EphemeralInventory.getVersion(smartObjectId, bob) + 1;
    EphemeralInventory.setVersion(smartObjectId, bob, newEphemeralVersion);
    vm.stopPrank();

    // Try to remove - should fail because the item version doesn't match ephemeral inventory version
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_Ephemeral_InsufficientQuantity.selector,
        smartObjectId,
        bob,
        ephemeralSingletonItemId,
        1,
        0
      )
    );
    inventoryOwnershipSystem.removeItemFromInventory(ephemeralSmartObjectId, ephemeralSingletonItemId, 1);
    assertEq(
      ownershipSystem.owner(ephemeralSingletonItemId),
      address(0),
      "Ephemeral singleton item should have no owner after version bump"
    );
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

  // Helper function to simulate a proper system-to-system call to assignToAccount
  function _simulateAssignToAccountCall(uint256 assignObjectId, address to) internal {
    // Call the ownership system through our mock system to get callCount > 1
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryOwnershipInteractSystem.callAssignOwnerToInventory.selector,
        assignObjectId,
        to
      )
    );
  }

  // Helper function to simulate a proper system-to-system call to removeFromAccount
  function _simulateRemoveFromAccountCall(uint256 removeObjectId, address from) internal {
    // Call the ownership system through our mock system to get callCount > 1
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryOwnershipInteractSystem.callRemoveOwnerFromInventory.selector,
        removeObjectId,
        from
      )
    );
  }
}
