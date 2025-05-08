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
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, DeployableState, InventoryItem, EphemeralInvCapacity, CharactersByAccount, LocationData, InventoryByEphemeral, InventoryByEphemeralData, EphemeralInventory, EphemeralInvItem, EphemeralInvItemData } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { State } from "../../src/codegen/common.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryOwnershipSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams, CreateInventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock system to properly test system-to-system calls
contract MockInventoryInteractSystem is System {
  // Calls from this mock will have callCount > 1
  // Call the inventory system deposit function
  function callInventoryDeposit(uint256 targetInventoryId, InventoryItemParams[] memory items) public {
    inventorySystem.depositInventory(targetInventoryId, items);
  }
  // Call the inventory system withdraw function
  function callInventoryWithdraw(uint256 targetInventoryId, InventoryItemParams[] memory items) public {
    inventorySystem.withdrawInventory(targetInventoryId, items);
  }

  // Add new functions to call ephemeral inventory system
  function callEphemeralDeposit(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public {
    ephemeralInventorySystem.depositEphemeral(smartObjectId, ephemeralOwner, items);
  }

  function callEphemeralWithdraw(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public {
    ephemeralInventorySystem.withdrawEphemeral(smartObjectId, ephemeralOwner, items);
  }
}

contract EphemeralInventoryTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 inventoryObjectId;

  bytes32 tenantId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;

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

  uint256 inventoryObjectClassId;

  // Mock system address
  MockInventoryInteractSystem mockSystem;
  ResourceId mockSystemId;

  uint256 item1ObjectId;
  uint256 item2ObjectId;
  uint256 item3ObjectId;
  uint256 transferItemObjectId;

  // Add these constants to your test file
  uint256 constant CREATE_SINGLETON_ITEM_ID = 9001;
  uint256 constant CREATE_NON_SINGLETON_ITEM_ID = 0;
  uint256 constant CREATE_SINGLETON_ITEM_TYPE_ID = 9000;
  uint256 constant CREATE_NON_SINGLETON_ITEM_TYPE_ID = 9090;

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
    tenantId = Tenant.get();

    // Setup smart object IDs
    inventoryObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("mockInvInteract");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockInventoryInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    // Register class and setup smart object state
    inventoryObjectClassId = uint256(keccak256(abi.encodePacked(tenantId, SMART_OBJECT_TYPE_ID)));

    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = inventorySystem.toResourceId();
    systemIds[5] = ephemeralInventorySystem.toResourceId();
    systemIds[6] = mockSystemId;

    entitySystem.registerClass(inventoryObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(inventoryObjectClassId, inventoryObjectId, alice);

    // Setup deployable state for inventory
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        inventoryObjectId,
        "SSU",
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      ),
      0
    );

    // Configure access control to allow the mock system to call inventory system
    bytes4[2] memory inventoryFunctionSelectors = [
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];
    for (uint i = 0; i < inventoryFunctionSelectors.length; i++) {
      CallAccess.set(inventorySystem.toResourceId(), inventoryFunctionSelectors[i], address(mockSystem), true);
    }

    // Configure access control to allow the mock system to call ephemeral inventory system
    bytes4[2] memory ephemeralFunctionSelectors = [
      EphemeralInventorySystem.depositEphemeral.selector,
      EphemeralInventorySystem.withdrawEphemeral.selector
    ];
    for (uint i = 0; i < ephemeralFunctionSelectors.length; i++) {
      CallAccess.set(ephemeralInventorySystem.toResourceId(), ephemeralFunctionSelectors[i], address(mockSystem), true);
    }

    // Set capacity for the inventory
    uint256 capacity = 1000;
    inventorySystem.setCapacity(inventoryObjectId, capacity);

    // Calculate itemObjectIds
    item1ObjectId = _calculateObjectId(ITEM_TYPE_ID, ITEM1_ID, true); // Singleton item
    item2ObjectId = _calculateObjectId(ITEM_TYPE_ID_NON_SINGLETON, 0, false); // Non-singleton item
    transferItemObjectId = _calculateObjectId(TRANSFER_ITEM_TYPE_ID, 0, false); // Non-singleton item

    // Set up item records with the correct parameters
    _setupEntityRecord(item1ObjectId, ITEM_TYPE_ID, ITEM1_ID, ITEM_VOLUME);
    _setupEntityRecord(item2ObjectId, ITEM_TYPE_ID_NON_SINGLETON, 0, ITEM_VOLUME);
    _setupEntityRecord(transferItemObjectId, TRANSFER_ITEM_TYPE_ID, 0, ITEM_VOLUME);

    // Set ephemeral capacity for the smart object
    uint256 ephemeralCapacity = 1000;
    inventorySystem.setEphemeralCapacity(inventoryObjectId, ephemeralCapacity);

    vm.stopPrank();
  }

  // Helper function to calculate ephemeral smart object ID
  function getEphemeralSmartObjectId(uint256 smartObjectId, address ephemeralOwner) internal pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(smartObjectId, ephemeralOwner)));
  }

  // Test creating and depositing items to ephemeral inventory
  function testCreateAndDepositEphemeral() public {
    // Create a valid entity without assigning it
    uint256 unassignedObjectId = _calculateObjectId(123457, 123456, true);
    vm.prank(deployer);
    entitySystem.instantiate(inventoryObjectClassId, unassignedObjectId, alice);

    // Calculate object IDs for the test items
    uint256 singletonObjectId = _calculateObjectId(CREATE_SINGLETON_ITEM_TYPE_ID, CREATE_SINGLETON_ITEM_ID, true);
    uint256 nonSingletonObjectId = _calculateObjectId(
      CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      CREATE_NON_SINGLETON_ITEM_ID,
      false
    );

    // Create a reusable parameter object for multiple test cases
    CreateInventoryItemParams[] memory testItems = new CreateInventoryItemParams[](1);
    testItems[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 1,
      volume: ITEM_VOLUME
    });

    // turn off access control for the ephemeral inventory system (to test the first revert case)
    bytes4[2] memory ephemeralInventoryOnlyOwnerOrCallAccessSelectors = [
      EphemeralInventorySystem.createAndDepositEphemeral.selector,
      EphemeralInventorySystem.depositEphemeral.selector
    ];

    vm.startPrank(deployer);
    for (uint256 i = 0; i < ephemeralInventoryOnlyOwnerOrCallAccessSelectors.length; i++) {
      accessConfigSystem.setAccessEnforcement(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryOnlyOwnerOrCallAccessSelectors[i],
        false
      );
    }
    vm.stopPrank();

    vm.prank(bob, deployer);
    // Try to call createAndDepositEphemeral with the unassigned object
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidSmartObjectId.selector,
        unassignedObjectId
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(unassignedObjectId, bob, testItems);

    vm.startPrank(deployer);
    for (uint256 i = 0; i < ephemeralInventoryOnlyOwnerOrCallAccessSelectors.length; i++) {
      accessConfigSystem.setAccessEnforcement(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryOnlyOwnerOrCallAccessSelectors[i],
        true
      );
    }
    vm.stopPrank();

    vm.startPrank(bob, deployer);
    // Test for wrong tenant ID - reuse the same array but modify the values
    testItems[0].tenantId = bytes32(uint256(0x123)); // Wrong tenant ID
    testItems[0].smartObjectId = uint256(keccak256(abi.encodePacked(testItems[0].tenantId, CREATE_SINGLETON_ITEM_ID)));

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidTenantId.selector,
        testItems[0].smartObjectId,
        testItems[0].tenantId
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, testItems);

    // Test for invalid singleton object ID - reuse the array
    testItems[0].tenantId = tenantId; // Restore correct tenant ID
    testItems[0].smartObjectId = uint256(0x456); // Not matching hash

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemObjectId.selector,
        testItems[0].smartObjectId
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, testItems);

    // Test for invalid singleton quantity - reuse the array
    testItems[0].smartObjectId = singletonObjectId; // Restore correct object ID
    testItems[0].quantity = 2; // Invalid for singleton

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemDepositQuantity.selector,
        singletonObjectId,
        2
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, testItems);

    // Test for non-singleton item with invalid object ID
    testItems[0].smartObjectId = uint256(0x789); // Not matching hash
    testItems[0].typeId = CREATE_NON_SINGLETON_ITEM_TYPE_ID;
    testItems[0].itemId = 0;
    testItems[0].quantity = 9;

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemObjectId.selector,
        testItems[0].smartObjectId
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, testItems);

    // Test for non-singleton item with invalid quantity
    testItems[0].smartObjectId = nonSingletonObjectId; // Correct non-singleton object ID
    testItems[0].quantity = 0; // Invalid quantity

    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidItemDepositQuantity.selector,
        nonSingletonObjectId,
        0
      )
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, testItems);

    vm.stopPrank();

    // Create parameters for creating new items (success case)
    CreateInventoryItemParams[] memory createItems = new CreateInventoryItemParams[](2);

    // First item: singleton item
    createItems[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 1,
      volume: ITEM_VOLUME
    });

    // Second item: non-singleton item
    createItems[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0,
      quantity: 3,
      volume: ITEM_VOLUME
    });

    // Verify initial state - ephemeral inventory shouldn't exist yet and the objects should not exist
    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(inventoryObjectId, bob);
    assertEq(InventoryByEphemeral.getExists(ephemeralSmartObjectId), false);
    assertEq(EntityRecord.getExists(singletonObjectId), false);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), false);

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, inventoryObjectId, State.ANCHORED)
    );
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, createItems);
    vm.stopPrank();

    // Bring online and create and deposit items
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.createAndDepositEphemeral(inventoryObjectId, bob, createItems);
    vm.stopPrank();

    // Verify final state data
    assertEq(EntityRecord.getExists(singletonObjectId), true);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), true);

    // Verify the ephemeral inventory has been created and linked
    InventoryByEphemeralData memory ephemeralObjectData = InventoryByEphemeral.get(ephemeralSmartObjectId);
    assertEq(ephemeralObjectData.exists, true);
    assertEq(ephemeralObjectData.smartObjectId, inventoryObjectId);
    assertEq(ephemeralObjectData.ephemeralOwner, bob);

    // Verify items were added to the ephemeral inventory
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 2);

    // Verify specific items exist in the ephemeral inventory
    assertTrue(EphemeralInvItem.getExists(inventoryObjectId, bob, singletonObjectId));
    assertTrue(EphemeralInvItem.getExists(inventoryObjectId, bob, nonSingletonObjectId));

    // Verify quantities
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, singletonObjectId), 1);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, nonSingletonObjectId), 3);

    // Verify capacity was set from the EphemeralInvCapacity
    assertEq(
      EphemeralInventory.getCapacity(inventoryObjectId, bob),
      EphemeralInvCapacity.getCapacity(inventoryObjectId)
    );

    // Verify used capacity is updated correctly
    uint256 expectedUsedCapacity = ITEM_VOLUME * 1 + ITEM_VOLUME * 3;
    assertEq(EphemeralInventory.getUsedCapacity(inventoryObjectId, bob), expectedUsedCapacity);
  }

  // Test depositing items to ephemeral inventory
  function testDepositEphemeral() public {
    // Prepare item params for deposit
    InventoryItemParams[] memory items = new InventoryItemParams[](2);

    items[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    items[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 2 });

    vm.startPrank(deployer);
    DeployableState.setCurrentState(inventoryObjectId, State.ANCHORED);
    vm.stopPrank();

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, inventoryObjectId, State.ANCHORED)
    );
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, items);
    vm.stopPrank();

    // Bring state to ONLINE
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Test revert: non-existent entity record
    InventoryItemParams[] memory invalidItems = new InventoryItemParams[](1);
    invalidItems[0] = InventoryItemParams({
      smartObjectId: 999999, // Non-existent ID
      quantity: 1
    });

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_NonExistentEntityRecord.selector,
        "InventorySystem: non-existent entity record",
        999999
      )
    );
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, invalidItems);
    vm.stopPrank();

    // Test revert: invalid ephemeral owner (same as smart object owner)
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InvalidEphemeralOwner.selector,
        inventoryObjectId,
        alice
      )
    );
    ephemeralInventorySystem.depositEphemeral(
      inventoryObjectId,
      alice, // Using the object owner as ephemeral owner should fail
      new InventoryItemParams[](0)
    );
    vm.stopPrank();

    // Test revert: insufficient capacity
    // First set a very small capacity
    vm.startPrank(deployer);
    inventorySystem.setEphemeralCapacity(inventoryObjectId, 50); // Smaller than our items need
    vm.stopPrank();

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        EphemeralInventorySystem.EphemeralInventory_InsufficientCapacity.selector,
        "EphemeralInventorySystem: insufficient capacity",
        50,
        ITEM_VOLUME * 1 // the first ITEM_VOLUME breaks capacity
      )
    );
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, items);
    vm.stopPrank();

    // Set proper capacity and verify initial ephemeral inventory state (should be empty)
    vm.startPrank(deployer);
    inventorySystem.setEphemeralCapacity(inventoryObjectId, 1000);
    vm.stopPrank();

    uint256 ephemeralSmartObjectId = getEphemeralSmartObjectId(inventoryObjectId, bob);

    // Verify initial ephemeral inventory state - should not exist yet
    assertEq(InventoryByEphemeral.getExists(ephemeralSmartObjectId), false);
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 0);
    assertEq(EphemeralInventory.getUsedCapacity(inventoryObjectId, bob), 0);

    // Call depositEphemeral successfully
    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, items);
    vm.stopPrank();

    // Verify the ephemeral inventory has been created and linked
    InventoryByEphemeral.getExists(ephemeralSmartObjectId);
    assertEq(InventoryByEphemeral.getExists(ephemeralSmartObjectId), true);
    assertEq(InventoryByEphemeral.getSmartObjectId(ephemeralSmartObjectId), inventoryObjectId);
    assertEq(InventoryByEphemeral.getEphemeralOwner(ephemeralSmartObjectId), bob);

    // Verify items were added to the ephemeral inventory
    uint256[] memory ephemeralItems = EphemeralInventory.getItems(inventoryObjectId, bob);
    assertEq(ephemeralItems.length, 2);
    assertEq(ephemeralItems[0], item1ObjectId);
    assertEq(ephemeralItems[1], item2ObjectId);

    // Verify item data is correct
    EphemeralInvItemData memory item1Data = EphemeralInvItem.get(inventoryObjectId, bob, item1ObjectId);
    EphemeralInvItemData memory item2Data = EphemeralInvItem.get(inventoryObjectId, bob, item2ObjectId);

    assertEq(item1Data.quantity, 1);
    assertEq(item1Data.index, 0);
    assertEq(item2Data.quantity, 2);
    assertEq(item2Data.index, 1);

    // Verify used capacity is updated correctly
    uint256 expectedUsedCapacity = ITEM_VOLUME * 3; // 1 + 2 = 3 items
    assertEq(EphemeralInventory.getUsedCapacity(inventoryObjectId, bob), expectedUsedCapacity);

    // Test the case where inventoryObjectId is unanchored and reanchored
    // This should bump the version and the ephemeral inventory should sync to the new version

    // First, verify the current version
    assertEq(Inventory.getVersion(inventoryObjectId), 1);
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, bob), 1);

    // Unanchor the inventory which destroys current state
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 20 minutes);
    deployableSystem.unanchor(inventoryObjectId);

    // Re-anchor and bring online - this recreates the smart object with a new version
    deployableSystem.anchor(
      inventoryObjectId,
      alice,
      LocationData({ solarSystemId: 30000142, x: 100, y: 100, z: 100 })
    );
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Verify version is bumped for the main inventory
    assertEq(Inventory.getVersion(inventoryObjectId), 2);

    // Create new deposit params
    InventoryItemParams[] memory newItemParams = new InventoryItemParams[](3);

    newItemParams[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    newItemParams[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 3 });

    newItemParams[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 4 });

    // Deposit items to ephemeral inventory after version bump
    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, newItemParams);
    vm.stopPrank();

    // Verify ephemeral inventory version is updated to match main inventory
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, bob), 2);

    // Verify items are correctly added with the expected quantities and indices
    uint256[] memory updatedItems = EphemeralInventory.getItems(inventoryObjectId, bob);
    assertEq(updatedItems.length, 3);

    // Items should be re-added
    assertEq(updatedItems[0], item1ObjectId);
    assertEq(updatedItems[1], item2ObjectId);
    assertEq(updatedItems[2], transferItemObjectId);

    // Check item data is correct
    EphemeralInvItemData memory newItem1Data = EphemeralInvItem.get(inventoryObjectId, bob, item1ObjectId);
    EphemeralInvItemData memory newItem2Data = EphemeralInvItem.get(inventoryObjectId, bob, item2ObjectId);
    EphemeralInvItemData memory newTransferItemData = EphemeralInvItem.get(
      inventoryObjectId,
      bob,
      transferItemObjectId
    );

    assertEq(newItem1Data.quantity, 1);
    assertEq(newItem1Data.index, 0); // Should use the same index as before
    assertEq(newItem2Data.quantity, 3);
    assertEq(newItem2Data.index, 1); // Should use the same index as before
    assertEq(newTransferItemData.quantity, 4);
    assertEq(newTransferItemData.index, 2); // Should get a new index as it was not added before

    // Check capacity is updated correctly
    uint256 newCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);
    assertEq(newCapacityUsed, ITEM_VOLUME * 8); // 1 + 3 + 4 = 8 items
  }

  // Test withdrawing items from ephemeral inventory
  function testWithdrawEphemeral() public {
    // First set up ephemeral inventory with items
    InventoryItemParams[] memory itemParams = new InventoryItemParams[](3);

    itemParams[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    itemParams[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 4 });

    itemParams[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 5 });

    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Deposit items to ephemeral inventory
    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, itemParams);
    vm.stopPrank();

    // We should now have 3 items with quantities 1, 4 and 5, total capacity used = 1000
    uint256[] memory ephemeralItems = EphemeralInventory.getItems(inventoryObjectId, bob);
    assertEq(ephemeralItems.length, 3);
    assertEq(ephemeralItems[0], item1ObjectId);
    assertEq(ephemeralItems[1], item2ObjectId);
    assertEq(ephemeralItems[2], transferItemObjectId);
    uint256 initialCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);
    assertEq(initialCapacityUsed, ITEM_VOLUME * 10);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item1ObjectId), 1);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item2ObjectId), 4);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, transferItemObjectId), 5);

    // Create withdrawal params
    InventoryItemParams[] memory items = new InventoryItemParams[](2);

    items[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 4 // Withdraw 4 of 4
    });

    items[1] = InventoryItemParams({
      smartObjectId: transferItemObjectId,
      quantity: 1 // Withdraw 1 of 5
    });

    // Test revert: incorrect state
    vm.prank(deployer);
    DeployableState.setCurrentState(inventoryObjectId, State.UNANCHORED);

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, inventoryObjectId, State.UNANCHORED)
    );
    ephemeralInventorySystem.withdrawEphemeral(inventoryObjectId, bob, items);
    vm.stopPrank();

    // Reset state to ONLINE
    vm.prank(deployer);
    DeployableState.setCurrentState(inventoryObjectId, State.ONLINE);

    // Test revert: invalid withdrawal quantity
    InventoryItemParams[] memory invalidItems = new InventoryItemParams[](1);
    invalidItems[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 10 // Trying to withdraw more than available
    });

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_Ephemeral_InsufficientQuantity.selector,
        inventoryObjectId,
        bob,
        item2ObjectId,
        10,
        4 // We have 4 available
      )
    );
    ephemeralInventorySystem.withdrawEphemeral(inventoryObjectId, bob, invalidItems);
    vm.stopPrank();

    // Now perform valid withdrawal
    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.withdrawEphemeral(inventoryObjectId, bob, items);
    vm.stopPrank();

    // Verify final state
    EphemeralInvItemData memory item1ObjectData = EphemeralInvItem.get(inventoryObjectId, bob, item1ObjectId);
    EphemeralInvItemData memory item2ObjectData = EphemeralInvItem.get(inventoryObjectId, bob, item2ObjectId);
    EphemeralInvItemData memory transferItemObjectData = EphemeralInvItem.get(
      inventoryObjectId,
      bob,
      transferItemObjectId
    );
    assertEq(item1ObjectData.quantity, 1); // Was 1, now 1
    assertEq(item2ObjectData.quantity, 0); // Was 2, now 0
    assertEq(transferItemObjectData.quantity, 4); // Was 5, now 4

    // Item 2 should be completely removed
    uint256[] memory remainingItems = EphemeralInventory.getItems(inventoryObjectId, bob);
    assertEq(remainingItems.length, 2);
    assertEq(remainingItems[0], item1ObjectId);
    assertEq(remainingItems[1], transferItemObjectId);

    assertEq(EphemeralInvItem.getExists(inventoryObjectId, bob, item2ObjectId), false);

    // Check capacity
    uint256 objectCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);
    assertEq(objectCapacityUsed, ITEM_VOLUME * 5); // 1 + 4

    // Test the case where inventoryObjectId is unanchored and then re-anchored
    // This should bump the version and withdrawal should fail

    // First, let's simulate unanchoring which invalidates the current state
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 20 minutes);
    deployableSystem.unanchor(inventoryObjectId);

    // Re-anchor and bring online - this recreates the smart object at a new version
    deployableSystem.anchor(
      inventoryObjectId,
      alice,
      LocationData({ solarSystemId: 30000142, x: 100, y: 100, z: 100 })
    );
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Verify version is bumped for the main inventory
    assertEq(Inventory.getVersion(inventoryObjectId), 2);

    // Attempt to withdraw the transferItemObjectId item
    // On first call, ephemeral inventory version will be updated to match main inventory
    // Then withdrawal should fail since the items from the previous version are gone
    // before unanchoring we had 4 of the transferItemObjectId item
    InventoryItemParams[] memory oldVersionItems = new InventoryItemParams[](1);
    oldVersionItems[0] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 1 });

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_Ephemeral_InsufficientQuantity.selector,
        inventoryObjectId,
        bob,
        transferItemObjectId,
        1,
        0 // We now have 0 available
      )
    );
    ephemeralInventorySystem.withdrawEphemeral(inventoryObjectId, bob, oldVersionItems);
    vm.stopPrank();
  }

  // Test ephemeral to inventory transfer (and vice versa)
  function test_EphemeralInventory_EphemeralToInventoryTransfer() public {
    // First, bring inventory online (required for ephemeral operations)
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);

    // Create items in the main inventory first
    InventoryItemParams[] memory mainInventoryItems = new InventoryItemParams[](3);
    mainInventoryItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });
    mainInventoryItems[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 4 });
    mainInventoryItems[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 5 });

    // Add items to the main inventory
    inventorySystem.depositInventory(inventoryObjectId, mainInventoryItems);
    vm.stopPrank();

    // Verify items are in the main inventory
    assertEq(Inventory.lengthItems(inventoryObjectId), 3);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item1ObjectId), 1);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 4);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, transferItemObjectId), 5);

    // Verify initial ephemeral inventory state - should be empty
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 0);

    // Transfer items from the main inventory to Bob's ephemeral inventory
    InventoryItemParams[] memory toEphemeralItems = new InventoryItemParams[](2);
    toEphemeralItems[0] = InventoryItemParams({
      smartObjectId: item1ObjectId,
      quantity: 1 // Transfer all from main to ephemeral
    });
    toEphemeralItems[1] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 2 // Transfer 2 of 4 from main to ephemeral
    });

    // Simulate main inventory to ephemeral transfer
    vm.prank(alice, deployer);
    _simulateToEphemeralTransferCall(inventoryObjectId, bob, toEphemeralItems);

    // Verify the items have been moved to Bob's ephemeral inventory
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 2);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item1ObjectId), 1);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item2ObjectId), 2);

    // Verify the items have been removed or reduced in the main inventory
    assertEq(Inventory.lengthItems(inventoryObjectId), 2); // item1 should be completely gone
    assertEq(InventoryItem.getExists(inventoryObjectId, item1ObjectId), false);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 2); // was 4, now 2
    assertEq(InventoryItem.getQuantity(inventoryObjectId, transferItemObjectId), 5); // unchanged

    // Verify versions match
    uint256 mainVersion = Inventory.getVersion(inventoryObjectId);
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, bob), mainVersion);

    // Now transfer some items back from ephemeral to main inventory
    InventoryItemParams[] memory toMainItems = new InventoryItemParams[](1);
    toMainItems[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 1 // Transfer 1 of 2 back to main
    });

    // Simulate ephemeral to main inventory transfer
    vm.prank(bob, deployer);
    _simulateFromEphemeralTransferCall(inventoryObjectId, bob, toMainItems);

    // Verify items in Bob's ephemeral inventory have decreased
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 2);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item1ObjectId), 1); // unchanged
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item2ObjectId), 1); // was 2, now 1

    // Verify items in main inventory have increased
    assertEq(Inventory.lengthItems(inventoryObjectId), 2);
    assertEq(InventoryItem.getExists(inventoryObjectId, item1ObjectId), false); // still gone
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 3); // was 2, now 3
    assertEq(InventoryItem.getQuantity(inventoryObjectId, transferItemObjectId), 5); // unchanged

    // Verify capacity usage
    uint256 mainCapacityUsed = Inventory.getUsedCapacity(inventoryObjectId);
    uint256 bobCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);

    assertEq(mainCapacityUsed, ITEM_VOLUME * 8); // 3 + 5 = 8 items
    assertEq(bobCapacityUsed, ITEM_VOLUME * 2); // 1 + 1 = 2 items

    // Verify versions still match
    mainVersion = Inventory.getVersion(inventoryObjectId);
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, bob), mainVersion);

    // Test complete transfer from ephemeral back to main
    InventoryItemParams[] memory allRemainingItems = new InventoryItemParams[](2);
    allRemainingItems[0] = InventoryItemParams({
      smartObjectId: item1ObjectId,
      quantity: 1 // Transfer all the item1 back
    });
    allRemainingItems[1] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 1 // Transfer remaining item2 back
    });

    // Simulate the complete transfer back
    vm.prank(bob, deployer);
    _simulateFromEphemeralTransferCall(inventoryObjectId, bob, allRemainingItems);

    // Verify Bob's ephemeral inventory is now empty
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 0);
    assertEq(EphemeralInvItem.getExists(inventoryObjectId, bob, item1ObjectId), false);
    assertEq(EphemeralInvItem.getExists(inventoryObjectId, bob, item2ObjectId), false);

    // Verify all items are back in the main inventory
    assertEq(Inventory.lengthItems(inventoryObjectId), 3);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item1ObjectId), 1);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, item2ObjectId), 4);
    assertEq(InventoryItem.getQuantity(inventoryObjectId, transferItemObjectId), 5);

    // Verify final capacity
    mainCapacityUsed = Inventory.getUsedCapacity(inventoryObjectId);
    bobCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);

    assertEq(mainCapacityUsed, ITEM_VOLUME * 10); // 1 + 4 + 5 = 10 items (back to original)
    assertEq(bobCapacityUsed, 0); // Empty
  }

  // Test inter-ephemeral transfer
  function test_EphemeralInventory_CrossEphemeralTransfer() public {
    // Create two ephemeral inventories
    // First, bring inventory online (required for ephemeral operations)
    vm.startPrank(alice, deployer);
    deployableSystem.bringOnline(inventoryObjectId);
    vm.stopPrank();

    // Initial items to add to Bob's ephemeral inventory
    InventoryItemParams[] memory bobItems = new InventoryItemParams[](3);
    bobItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });
    bobItems[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 4 });
    bobItems[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 5 });

    // add items to the first ephemeral inventory (Bob's)
    vm.startPrank(bob, deployer);
    ephemeralInventorySystem.depositEphemeral(inventoryObjectId, bob, bobItems);
    vm.stopPrank();

    // Verify Bob's initial inventory state
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 3);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item1ObjectId), 1);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item2ObjectId), 4);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, transferItemObjectId), 5);

    // Verify Charlie's inventory state
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, charlie), 0);

    // Prepare transfer items from Bob to Charlie
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](2);
    transferItems[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 2 // Transfer 2 of 4
    });
    transferItems[1] = InventoryItemParams({
      smartObjectId: transferItemObjectId,
      quantity: 3 // Transfer 3 of 5
    });

    // simulate a cross-ephemeral transfer from the first ephemeral inventory to the second
    vm.prank(bob, deployer); // Bob must be the caller since we are withdrawing from his inventory
    _simulateCrossEphemeralTransferCall(
      inventoryObjectId,
      bob, // from ephemeral owner
      charlie, // to ephemeral owner
      transferItems
    );

    // verify the second ephemeral inventory (Charlie's) now has the items
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, charlie), 2);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, charlie, item2ObjectId), 2);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, charlie, transferItemObjectId), 3);

    // verify the first ephemeral inventory (Bob's) has the remaining items
    assertEq(EphemeralInventory.lengthItems(inventoryObjectId, bob), 3);
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item1ObjectId), 1); // unchanged
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, item2ObjectId), 2); // was 4, now 2
    assertEq(EphemeralInvItem.getQuantity(inventoryObjectId, bob, transferItemObjectId), 2); // was 5, now 2

    // verify the main inventory has no items (items are only in ephemeral inventories)
    assertEq(Inventory.lengthItems(inventoryObjectId), 0);

    // verify the version of the first ephemeral inventory is the same as the main inventory
    uint256 mainVersion = Inventory.getVersion(inventoryObjectId);
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, bob), mainVersion);

    // verify the version of the second ephemeral inventory is the same as the main inventory
    assertEq(EphemeralInventory.getVersion(inventoryObjectId, charlie), mainVersion);

    // Verify capacity usage in both ephemeral inventories
    uint256 bobCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, bob);
    uint256 charlieCapacityUsed = EphemeralInventory.getUsedCapacity(inventoryObjectId, charlie);

    // Expected capacity: Bob has 1 + 2 + 2 = 5 items, Charlie has 2 + 3 = 5 items
    assertEq(bobCapacityUsed, ITEM_VOLUME * 5);
    assertEq(charlieCapacityUsed, ITEM_VOLUME * 5);
  }

  // Helper functions to simulate a proper inventory to ephemeral transfers
  function _simulateToEphemeralTransferCall(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory transferItems
  ) internal {
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockInventoryInteractSystem.callInventoryWithdraw.selector, smartObjectId, transferItems)
    );
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callEphemeralDeposit.selector,
        smartObjectId,
        ephemeralOwner,
        transferItems
      )
    );
  }

  function _simulateFromEphemeralTransferCall(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory transferItems
  ) internal {
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callEphemeralWithdraw.selector,
        smartObjectId,
        ephemeralOwner,
        transferItems
      )
    );
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockInventoryInteractSystem.callInventoryDeposit.selector, smartObjectId, transferItems)
    );
  }

  // Helper functions to simulate a proper inventory to inventory transfers
  function _simulateCrossEphemeralTransferCall(
    uint256 smartObjectId,
    address fromEphemeralOwner,
    address toEphemeralOwner,
    InventoryItemParams[] memory transferItems
  ) internal {
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callEphemeralWithdraw.selector,
        smartObjectId,
        fromEphemeralOwner,
        transferItems
      )
    );
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callEphemeralDeposit.selector,
        smartObjectId,
        toEphemeralOwner,
        transferItems
      )
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
}
