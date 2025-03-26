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
import { GlobalDeployableState, Inventory, Tenant, EntityRecord, DeployableState, InventoryItemData, InventoryItem, InventoryByItem, EphemeralInvCapacity, CharactersByAccount, LocationData } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { State } from "../../src/codegen/common.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryOwnershipSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

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
}

contract InventoryTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 smartObjectId;
  uint256 secondObjectId;

  bytes32 tenantId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SECOND_OBJECT_ID = 5678;
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

    // Setup smart object IDs
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);
    secondObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SECOND_OBJECT_ID, true);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("mockInvInteract");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockInventoryInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    // Register class and setup smart object state
    uint256 inventoryObjectClassId = uint256(keccak256(abi.encodePacked(tenantId, SMART_OBJECT_TYPE_ID)));

    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = inventorySystem.toResourceId();
    systemIds[6] = mockSystemId;

    entitySystem.registerClass(inventoryObjectClassId, systemIds);

    // instantiate the smart objects
    entitySystem.instantiate(inventoryObjectClassId, smartObjectId, alice);
    entitySystem.instantiate(inventoryObjectClassId, secondObjectId, bob);

    // Make sure deploy system is active
    GlobalDeployableState.setIsPaused(false);

    // Setup deployable state for first inventory
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        1,
        10,
        100000,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      )
    );

    // Setup deployable state for second inventory
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        secondObjectId,
        "SSU",
        EntityRecordParams({
          tenantId: tenantId,
          typeId: SMART_OBJECT_TYPE_ID,
          itemId: SECOND_OBJECT_ID,
          volume: 1000
        }),
        bob,
        1,
        10,
        100000,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      )
    );

    // Configure access control to allow the mock system to call inventory system
    ResourceId inventorySystemId = inventorySystem.toResourceId();
    bytes4[2] memory inventoryFunctionSelectors = [
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];
    for (uint i = 0; i < inventoryFunctionSelectors.length; i++) {
      CallAccess.set(inventorySystemId, inventoryFunctionSelectors[i], address(mockSystem), true);
    }

    // Set capacity for both inventories
    uint256 capacity = 1000;

    inventorySystem.setCapacity(smartObjectId, capacity);
    inventorySystem.setCapacity(secondObjectId, capacity);

    // Calculate itemObjectIds
    item1ObjectId = _calculateObjectId(ITEM_TYPE_ID, ITEM1_ID, true); // Singleton item
    item2ObjectId = _calculateObjectId(ITEM_TYPE_ID_NON_SINGLETON, 0, false); // Non-singleton item
    transferItemObjectId = _calculateObjectId(TRANSFER_ITEM_TYPE_ID, 0, false); // Non-singleton item

    // Set up item records with the correct parameters
    _setupEntityRecord(item1ObjectId, ITEM_TYPE_ID, ITEM1_ID, ITEM_VOLUME);
    _setupEntityRecord(item2ObjectId, ITEM_TYPE_ID_NON_SINGLETON, 0, ITEM_VOLUME);
    _setupEntityRecord(transferItemObjectId, TRANSFER_ITEM_TYPE_ID, 0, ITEM_VOLUME);
    vm.stopPrank();
    vm.resumeGasMetering();
  }

  // Test setting inventory capacity
  function test_setCapacity() public {
    uint256 capacity = 10000;

    // Check initial capacity
    assertEq(Inventory.getCapacity(smartObjectId), 1000);

    // Try with invalid capacity
    vm.startPrank(deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InvalidCapacity.selector,
        "InventorySystem: storage capacity cannot be 0"
      )
    );
    inventorySystem.setCapacity(smartObjectId, 0);

    // Set valid capacity
    inventorySystem.setCapacity(smartObjectId, capacity);
    vm.stopPrank();
    // Verify capacity was set correctly
    assertEq(Inventory.getCapacity(smartObjectId), capacity);
  }

  // Test setting ephemeral inventory capacity
  function test_setEphemeralCapacity() public {
    uint256 ephemeralCapacity = 500;

    // Check initial capacity
    assertEq(EphemeralInvCapacity.getCapacity(smartObjectId), 0);

    // Set ephemeral capacity
    vm.startPrank(deployer);
    inventorySystem.setEphemeralCapacity(smartObjectId, ephemeralCapacity);
    vm.stopPrank();

    // Verify capacity was set correctly
    assertEq(EphemeralInvCapacity.getCapacity(smartObjectId), ephemeralCapacity);
  }

  // Test creating and depositing inventory items
  function test_createAndDepositInventory() public {
    // Calculate object IDs for the new items
    uint256 singletonObjectId = _calculateObjectId(CREATE_SINGLETON_ITEM_TYPE_ID, CREATE_SINGLETON_ITEM_ID, true);
    uint256 nonSingletonObjectId = _calculateObjectId(
      CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      CREATE_NON_SINGLETON_ITEM_ID,
      false
    );

    // Test for singleton item with invalid tenant ID
    bytes32 wrongTenantId = bytes32(uint256(0x123)); // Different from the test tenantId
    uint256 wrongTenantObjectId = uint256(keccak256(abi.encodePacked(wrongTenantId, CREATE_SINGLETON_ITEM_ID)));

    CreateInventoryItemParams[] memory invalidTenantItems = new CreateInventoryItemParams[](1);
    invalidTenantItems[0] = CreateInventoryItemParams({
      smartObjectId: wrongTenantObjectId,
      tenantId: wrongTenantId, // Wrong tenant ID
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 1,
      volume: ITEM_VOLUME
    });

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidTenantId.selector, wrongTenantObjectId, wrongTenantId)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, invalidTenantItems);

    // Test for singleton item with invalid object ID
    uint256 wrongSingletonObjectId = uint256(0x456); // Not matching hash of tenantId and itemId

    CreateInventoryItemParams[] memory invalidObjectIdItems = new CreateInventoryItemParams[](1);
    invalidObjectIdItems[0] = CreateInventoryItemParams({
      smartObjectId: wrongSingletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 1,
      volume: ITEM_VOLUME
    });

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, wrongSingletonObjectId)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, invalidObjectIdItems);

    // Test for singleton item with invalid quantity
    CreateInventoryItemParams[] memory invalidQuantityItems = new CreateInventoryItemParams[](1);
    invalidQuantityItems[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 2, // Should be 1 for singleton items
      volume: ITEM_VOLUME
    });

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, singletonObjectId, 2)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, invalidQuantityItems);

    // Test for non-singleton item with invalid object ID
    uint256 wrongNonSingletonObjectId = uint256(0x789); // Not matching hash of typeId

    CreateInventoryItemParams[] memory invalidNonSingletonObjectItems = new CreateInventoryItemParams[](1);
    invalidNonSingletonObjectItems[0] = CreateInventoryItemParams({
      smartObjectId: wrongNonSingletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0, // For non-singleton items, itemId is zero
      quantity: 9,
      volume: ITEM_VOLUME
    });

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, wrongNonSingletonObjectId)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, invalidNonSingletonObjectItems);

    // Test for non-singleton item with invalid quantity
    CreateInventoryItemParams[] memory invalidNonSingletonQuantityItems = new CreateInventoryItemParams[](1);
    invalidNonSingletonQuantityItems[0] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0,
      quantity: 0, // Should be > 0 for non-singleton items
      volume: ITEM_VOLUME
    });

    vm.expectRevert(
      abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, nonSingletonObjectId, 0)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, invalidNonSingletonQuantityItems);
    vm.stopPrank();

    // Setup items array for successful case
    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    // Add the singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_SINGLETON_ITEM_TYPE_ID,
      itemId: CREATE_SINGLETON_ITEM_ID,
      quantity: 1, // Singleton can only have quantity of 1
      volume: ITEM_VOLUME
    });

    // Add the non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0, // For non-singleton items, itemId is zero
      quantity: 9, // Non-singleton can have any quantity
      volume: ITEM_VOLUME
    });

    // Verify initial state
    assertEq(Inventory.getItems(smartObjectId).length, 0);
    assertEq(Inventory.getUsedCapacity(smartObjectId), 0);
    assertEq(EntityRecord.getExists(singletonObjectId), false);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), false);

    // Test revert if not online
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.ANCHORED)
    );
    inventorySystem.createAndDepositInventory(smartObjectId, items);
    vm.stopPrank();

    // Bring online and create and deposit items
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    inventorySystem.createAndDepositInventory(smartObjectId, items);
    vm.stopPrank();

    // Verify final state data
    assertEq(EntityRecord.getExists(singletonObjectId), true);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), true);

    assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 10);
    uint256[] memory itemIds = Inventory.getItems(smartObjectId);
    assertEq(itemIds[0], singletonObjectId);
    assertEq(itemIds[1], nonSingletonObjectId);

    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, singletonObjectId);
    assertEq(itemData.exists, true);
    assertEq(itemData.quantity, 1);
    assertEq(itemData.index, 0);

    itemData = InventoryItem.get(smartObjectId, nonSingletonObjectId);
    assertEq(itemData.exists, true);
    assertEq(itemData.quantity, 9);
    assertEq(itemData.index, 1);

    assertEq(InventoryByItem.getInventoryObjectId(singletonObjectId), smartObjectId);
  }

  // Test depositing inventory items
  function test_depositInventory() public {
    // Prepare item params for deposit
    InventoryItemParams[] memory items = new InventoryItemParams[](2);

    items[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    items[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 2 });
    vm.pauseGasMetering();
    // Test revert: game is paused
    vm.startPrank(deployer); // Use deployer for GlobalDeployableState access
    GlobalDeployableState.setIsPaused(true);
    vm.stopPrank();

    vm.startPrank(alice, deployer);
    vm.expectRevert(abi.encodeWithSelector(DeployableSystem.Deployable_StateTransitionPaused.selector));
    inventorySystem.depositInventory(smartObjectId, items);
    vm.stopPrank();

    vm.startPrank(deployer); // Use deployer for GlobalDeployableState access
    GlobalDeployableState.setIsPaused(false);
    vm.stopPrank();

    // Test revert: incorrect state
    vm.startPrank(deployer); // Use deployer for DeployableState access
    DeployableState.setCurrentState(smartObjectId, State.ANCHORED);
    vm.stopPrank();

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.ANCHORED)
    );
    inventorySystem.depositInventory(smartObjectId, items);
    vm.stopPrank();

    // Bring state to ONLINE
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    // Test revert: non-existent entity record
    InventoryItemParams[] memory invalidItems = new InventoryItemParams[](1);
    invalidItems[0] = InventoryItemParams({
      smartObjectId: 999999, // Non-existent ID
      quantity: 1
    });

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_NonExistentEntityRecord.selector,
        "InventorySystem: non-existent entity record",
        999999
      )
    );
    inventorySystem.depositInventory(smartObjectId, invalidItems);
    vm.stopPrank();

    // Verify initial quantity and ownership state
    assertEq(InventoryItem.get(smartObjectId, item1ObjectId).quantity, 0);
    assertEq(InventoryItem.get(smartObjectId, item2ObjectId).quantity, 0);
    assertEq(InventoryItem.get(smartObjectId, transferItemObjectId).quantity, 0);
    assertEq(InventoryItem.get(secondObjectId, item1ObjectId).quantity, 0);
    assertEq(InventoryItem.get(secondObjectId, item2ObjectId).quantity, 0);
    assertEq(InventoryItem.get(secondObjectId, transferItemObjectId).quantity, 0);

    vm.startPrank(alice, deployer);
    // Call depositInventory directly
    inventorySystem.depositInventory(smartObjectId, items);
    vm.stopPrank();

    uint256[] memory itemsData = Inventory.getItems(smartObjectId);
    assertEq(itemsData.length, 2);
    assertEq(itemsData[0], item1ObjectId);
    assertEq(itemsData[1], item2ObjectId);

    InventoryItemData memory item1ObjectData = InventoryItem.get(smartObjectId, item1ObjectId);
    InventoryItemData memory item2ObjectData = InventoryItem.get(smartObjectId, item2ObjectId);

    assertEq(item1ObjectData.quantity, 1);
    assertEq(item1ObjectData.index, 0);
    assertEq(item2ObjectData.quantity, 2);
    assertEq(item2ObjectData.index, 1);

    // Verify ownership was assigned to inventory for singleton item
    assertEq(InventoryByItem.getInventoryObjectId(item1ObjectId), smartObjectId);

    // Test system-to-system call behavior
    // First deposit the transfer item into the first inventory
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 7 });

    vm.startPrank(alice, deployer);
    inventorySystem.depositInventory(smartObjectId, transferItems);
    vm.stopPrank();

    InventoryItemData memory transferItemObjectData = InventoryItem.get(smartObjectId, transferItemObjectId);
    // quantity should be 7
    assertEq(transferItemObjectData.quantity, 7);
    assertEq(transferItemObjectData.index, 2);

    // update the transfer item quantity to 5
    transferItems[0] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 5 });

    // bring second object online
    vm.startPrank(bob, deployer);
    fuelSystem.depositFuel(secondObjectId, 10000);
    deployableSystem.bringOnline(secondObjectId);
    vm.stopPrank();

    // Now simulate a proper system-to-system call using our mock system
    _simulateTransferCall(smartObjectId, secondObjectId, transferItems);

    // Verify the item was transferred between inventories and ownership tracked
    // Check item details
    item1ObjectData = InventoryItem.get(smartObjectId, item1ObjectId);
    item2ObjectData = InventoryItem.get(smartObjectId, item2ObjectId);
    transferItemObjectData = InventoryItem.get(smartObjectId, transferItemObjectId);
    InventoryItemData memory transferItemSecondObjectData = InventoryItem.get(secondObjectId, transferItemObjectId);

    // item1ObjectData
    assertEq(item1ObjectData.quantity, 1);
    assertEq(item1ObjectData.index, 0);

    // item2ObjectData
    assertEq(item2ObjectData.quantity, 2);
    assertEq(item2ObjectData.index, 1);

    // transferItemObjectData
    assertEq(transferItemObjectData.quantity, 2);
    assertEq(transferItemObjectData.index, 2);

    // transferItemSecondObjectData
    assertEq(transferItemSecondObjectData.quantity, 5);
    assertEq(transferItemSecondObjectData.index, 0);

    // both objects capacity should be 5
    assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 5); // 1 + 2 + 2
    assertEq(Inventory.getUsedCapacity(secondObjectId), ITEM_VOLUME * 5); // 5

    assertEq(Inventory.getItems(smartObjectId).length, 3); // item1, item3, transferItem
    assertEq(Inventory.getItems(secondObjectId).length, 1); // transferItem

    // Test revert: insufficient capacity
    transferItems[0].quantity = 6; // Would exceed capacity

    vm.startPrank(bob, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventorySystem.Inventory_InsufficientCapacity.selector,
        "InventorySystem: insufficient capacity",
        1000,
        ITEM_VOLUME * 11 // 5 + 6
      )
    );
    inventorySystem.depositInventory(secondObjectId, transferItems);
    vm.stopPrank();

    // Test re-anchoring behavior for deposit process
    // fetch the item index length
    uint256 itemIndexLength = Inventory.getItems(smartObjectId).length;
    assertEq(itemIndexLength, 3);

    // Unanchor and re-anchor deployable smart object
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 20 minutes);
    deployableSystem.unanchor(smartObjectId);
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 30000142, x: 100, y: 100, z: 100 }));
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    assertEq(Inventory.getVersion(smartObjectId), 2);
    assertEq(InventoryItem.getVersion(smartObjectId, item1ObjectId), 1);
    assertEq(InventoryItem.getVersion(smartObjectId, item2ObjectId), 1);
    assertEq(InventoryItem.getVersion(smartObjectId, transferItemObjectId), 1);

    // Deposit the same items again after re-anchoring
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 1 minutes);
    vm.resumeGasMetering();
    inventorySystem.depositInventory(smartObjectId, items);
    vm.pauseGasMetering();
    vm.stopPrank();

    // Verify that the items were deposited and ownership was tracked correctly
    itemIndexLength = Inventory.getItems(smartObjectId).length;
    assertEq(itemIndexLength, 3);

    item1ObjectData = InventoryItem.get(smartObjectId, item1ObjectId);
    item2ObjectData = InventoryItem.get(smartObjectId, item2ObjectId);

    // item1ObjectData
    assertEq(item1ObjectData.quantity, 1);
    assertEq(item1ObjectData.index, 0);
    assertEq(item1ObjectData.version, 2);

    // item2ObjectData
    assertEq(item2ObjectData.quantity, 2);
    assertEq(item2ObjectData.index, 1);
    assertEq(item2ObjectData.version, 2);

    // Test unanchoring and reanchoring secondObjectId
    // Unanchor and re-anchor the second deployable smart object
    vm.startPrank(bob, deployer);
    vm.warp(block.timestamp + 20 minutes);
    deployableSystem.unanchor(secondObjectId);
    deployableSystem.anchor(secondObjectId, bob, LocationData({ solarSystemId: 30000142, x: 200, y: 200, z: 200 }));
    deployableSystem.bringOnline(secondObjectId);
    vm.stopPrank();

    // Deposit the same transfer item again (quantity 6)
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 1 minutes);
    transferItems[0].quantity = 6;
    inventorySystem.depositInventory(smartObjectId, transferItems);
    vm.stopPrank();

    transferItemObjectData = InventoryItem.get(smartObjectId, transferItemObjectId);
    assertEq(transferItemObjectData.quantity, 6);
    assertEq(transferItemObjectData.index, 2);
    assertEq(transferItemObjectData.version, 2);

    // Prepare items for transfer
    transferItems[0].quantity = 4; // transfer 4

    // Simulate another transfer (smartObjectId -> secondObjectId)
    _simulateTransferCall(smartObjectId, secondObjectId, transferItems);

    // Verify final state after reanchoring and second transfer
    item1ObjectData = InventoryItem.get(smartObjectId, item1ObjectId);
    item2ObjectData = InventoryItem.get(smartObjectId, item2ObjectId);
    transferItemObjectData = InventoryItem.get(smartObjectId, transferItemObjectId);
    transferItemSecondObjectData = InventoryItem.get(secondObjectId, transferItemObjectId);

    // Verify individual item data in first inventory
    assertEq(item1ObjectData.quantity, 1);
    assertEq(item1ObjectData.index, 0);
    assertEq(item2ObjectData.quantity, 2);
    assertEq(item2ObjectData.index, 1);
    assertEq(transferItemObjectData.quantity, 2);
    assertEq(transferItemObjectData.index, 2);

    // Verify individual item data in second inventory
    assertEq(transferItemSecondObjectData.quantity, 4); // reset and sent 4
    assertEq(transferItemSecondObjectData.index, 0); // used the old index

    // Verify capacity usage (after anchor used capacity is properly reset)
    assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 5); // 1 + 2 + 2
    assertEq(Inventory.getUsedCapacity(secondObjectId), ITEM_VOLUME * 4); // 4

    // Verify inventory array lengths
    uint256 itemsFirstInv = Inventory.lengthItems(smartObjectId);
    uint256 itemsSecondInv = Inventory.lengthItems(secondObjectId);

    assertEq(itemsFirstInv, 3); // still 3 items in array
    assertEq(itemsSecondInv, 1); // 1 item in array
    vm.resumeGasMetering();
  }

  // Test withdrawing inventory items
  function test_withdrawInventory() public {
    // First set up inventory with items
    InventoryItemParams[] memory itemParams = new InventoryItemParams[](3);

    itemParams[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    itemParams[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 2 });

    itemParams[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 2 });

    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    inventorySystem.depositInventory(smartObjectId, itemParams);
    vm.stopPrank();

    // We should now have 3 items with quantities 1, 2 and 2, total capacity used = 500
    uint256[] memory inventoryItems = Inventory.getItems(smartObjectId);
    assertEq(inventoryItems.length, 3);
    assertEq(inventoryItems[0], item1ObjectId);
    assertEq(inventoryItems[1], item2ObjectId);
    assertEq(inventoryItems[2], transferItemObjectId);
    uint256 initialCapacityUsed = Inventory.getUsedCapacity(smartObjectId);
    assertEq(initialCapacityUsed, ITEM_VOLUME * 5);

    // Create withdrawal params
    InventoryItemParams[] memory items = new InventoryItemParams[](2);

    items[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 2 // Withdraw 2 of 2
    });

    items[1] = InventoryItemParams({
      smartObjectId: transferItemObjectId,
      quantity: 1 // Withdraw 1 of 2
    });

    // Test revert: game is paused
    vm.prank(deployer);
    GlobalDeployableState.setIsPaused(true);
    vm.startPrank(alice, deployer);
    vm.expectRevert(abi.encodeWithSelector(DeployableSystem.Deployable_StateTransitionPaused.selector));
    inventorySystem.withdrawInventory(smartObjectId, items);
    vm.stopPrank();

    vm.prank(deployer);
    GlobalDeployableState.setIsPaused(false);

    // Test revert: incorrect state
    vm.prank(deployer);
    DeployableState.setCurrentState(smartObjectId, State.UNANCHORED);

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    inventorySystem.withdrawInventory(smartObjectId, items);
    vm.stopPrank();

    // Reset state to ONLINE
    vm.prank(deployer);
    DeployableState.setCurrentState(smartObjectId, State.ONLINE);

    // Test revert: invalid withdrawal quantity
    InventoryItemParams[] memory invalidItems = new InventoryItemParams[](1);
    invalidItems[0] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 10 // Trying to withdraw more than available
    });

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InsufficientQuantity.selector,
        smartObjectId,
        item2ObjectId,
        10,
        2 // We have 2 available
      )
    );
    inventorySystem.withdrawInventory(smartObjectId, invalidItems);
    vm.stopPrank();

    // Now perform valid withdrawal
    vm.startPrank(alice, deployer);
    inventorySystem.withdrawInventory(smartObjectId, items);
    vm.stopPrank();

    // Verify final state
    InventoryItemData memory item1ObjectData = InventoryItem.get(smartObjectId, item1ObjectId);
    InventoryItemData memory item2ObjectData = InventoryItem.get(smartObjectId, item2ObjectId);
    InventoryItemData memory transferItemObjectData = InventoryItem.get(smartObjectId, transferItemObjectId);
    assertEq(item1ObjectData.quantity, 1); // Was 1, now 1
    assertEq(item2ObjectData.quantity, 0); // Was 2, now 0
    assertEq(transferItemObjectData.quantity, 1); // Was 2, now 1

    // Item 2 should be completely removed
    uint256[] memory remainingItems = Inventory.getItems(smartObjectId);
    assertEq(remainingItems.length, 2);
    assertEq(remainingItems[0], item1ObjectId);
    assertEq(remainingItems[1], transferItemObjectId);

    assertEq(InventoryItem.getExists(smartObjectId, item2ObjectId), false);

    // Check capacity
    uint256 objectCapacityUsed = Inventory.getUsedCapacity(smartObjectId);
    assertEq(objectCapacityUsed, ITEM_VOLUME * 2); // 1 + 1

    // Test the case where smartObjectId is unanchored and then re-anchored
    // This should bump the version and withdrawal should fail

    // First, let's simulate unanchoring which destroys the current state
    vm.startPrank(alice, deployer);
    vm.warp(block.timestamp + 20 minutes);
    deployableSystem.unanchor(smartObjectId);

    // Re-anchor and bring online - this recreates the smart object with a new version
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 30000142, x: 100, y: 100, z: 100 }));
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    // Verify version is bumped
    assertEq(Inventory.getVersion(smartObjectId), 2);

    // Attempt to withdraw the transferItemObjectId item
    // This should fail because the version has been bumped and items from the previous version no longer exist
    InventoryItemParams[] memory oldVersionItems = new InventoryItemParams[](1);
    oldVersionItems[0] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 1 });

    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        InventoryOwnershipSystem.InventoryOwnership_InsufficientQuantity.selector,
        smartObjectId,
        transferItemObjectId,
        1,
        0 // We now have 0 available (new version has no items)
      )
    );
    inventorySystem.withdrawInventory(smartObjectId, oldVersionItems);
    vm.stopPrank();
  }

  // Test complete removal of all items
  function test_withdrawAllItems() public {
    // First set up inventory with items
    InventoryItemParams[] memory itemParams = new InventoryItemParams[](3);

    itemParams[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    itemParams[1] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 2 });

    itemParams[2] = InventoryItemParams({ smartObjectId: transferItemObjectId, quantity: 2 });
    vm.pauseGasMetering();
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    inventorySystem.depositInventory(smartObjectId, itemParams);
    vm.stopPrank();

    // We now have 3 items with quantities 1, 2 and 2, total capacity used = 500
    uint256[] memory inventoryItems = Inventory.getItems(smartObjectId);
    assertEq(inventoryItems.length, 3);
    assertEq(inventoryItems[0], item1ObjectId);
    assertEq(inventoryItems[1], item2ObjectId);
    assertEq(inventoryItems[2], transferItemObjectId);
    uint256 initialCapacityUsed = Inventory.getUsedCapacity(smartObjectId);
    assertEq(initialCapacityUsed, ITEM_VOLUME * 5);
    assertEq(InventoryByItem.get(item1ObjectId), smartObjectId);
    vm.resumeGasMetering();
    // Perform withdrawal
    vm.startPrank(alice, deployer);
    inventorySystem.withdrawInventory(smartObjectId, itemParams);
    vm.stopPrank();
    vm.pauseGasMetering();
    // Verify final state
    uint256[] memory remainingItems = Inventory.getItems(smartObjectId);
    assertEq(remainingItems.length, 0); // No items should remain
    assertEq(Inventory.getUsedCapacity(smartObjectId), 0); // No capacity used
    assertEq(InventoryByItem.get(item1ObjectId), uint256(0));
    vm.resumeGasMetering();
  }

  // Test complex deposit and withdraw scenario
  function test_depositAndWithdrawMultipleItems() public {
    // set capacity to 10000
    vm.startPrank(deployer);
    Inventory.setCapacity(smartObjectId, 10000);
    Inventory.setCapacity(secondObjectId, 10000);
    vm.stopPrank();

    // Create multiple items for testing - aim for 2/3rds singletons, 1/3rd non-singletons
    uint256 testItemCount = 30;
    uint256[] memory testItemIds = new uint256[](testItemCount);
    uint256[] memory testTypeIds = new uint256[](testItemCount);
    uint256[] memory testObjectIds = new uint256[](testItemCount);
    bool[] memory isSingleton = new bool[](testItemCount);
    uint256[] memory volumes = new uint256[](testItemCount);

    // Create all test items from scratch
    for (uint256 i = 0; i < testItemCount; i++) {
      // Calculate type ID and item ID
      uint256 typeId = 4000 + i;

      // Make 2/3 of items singletons (20 out of 30)
      bool makeSingleton = (i < 20);
      uint256 itemId = makeSingleton ? (5000 + i) : 0;

      // Use smaller volumes for each item to stay within capacity limits
      uint256 itemVolume = 5 + i;

      // Calculate object ID
      uint256 objectId = _calculateObjectId(typeId, itemId, makeSingleton);

      // Store item data
      testItemIds[i] = itemId;
      testTypeIds[i] = typeId;
      testObjectIds[i] = objectId;
      isSingleton[i] = makeSingleton;
      volumes[i] = itemVolume;

      // Setup entity record for the item
      vm.startPrank(deployer);
      _setupEntityRecord(objectId, typeId, itemId, itemVolume);
      vm.stopPrank();
    }

    // Bring both inventories online
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    vm.startPrank(bob, deployer);
    fuelSystem.depositFuel(secondObjectId, 10000);
    deployableSystem.bringOnline(secondObjectId);
    vm.stopPrank();

    // Create itemParams array for deposit
    InventoryItemParams[] memory itemParams = new InventoryItemParams[](testItemCount);

    // Set quantities (1 for singletons, varying amounts for non-singletons)
    for (uint256 i = 0; i < testItemCount; i++) {
      uint256 quantity = isSingleton[i] ? 1 : (i + 2); // Non-singletons: 2-11

      itemParams[i] = InventoryItemParams({ smartObjectId: testObjectIds[i], quantity: quantity });
    }

    // Deposit items into alice's inventory
    vm.startPrank(alice, deployer);
    inventorySystem.depositInventory(smartObjectId, itemParams);
    vm.stopPrank();

    // Verify initial state - all items should be in alice's inventory
    uint256[] memory aliceItems = Inventory.getItems(smartObjectId);
    assertEq(aliceItems.length, testItemCount);

    // Transfer even-indexed items to bob's inventory (items 0, 2, 4, 6, 8)
    // This will create gaps in alice's inventory
    uint256 transferCount = testItemCount / 2;
    InventoryItemParams[] memory itemsToTransfer = new InventoryItemParams[](transferCount);

    for (uint256 i = 0; i < transferCount; i++) {
      uint256 index = i * 2; // Even indices: 0, 2, 4, 6, 8
      uint256 quantity = isSingleton[index] ? 1 : (index + 2);

      itemsToTransfer[i] = InventoryItemParams({
        smartObjectId: testObjectIds[index],
        quantity: quantity // Transfer full amount
      });
    }

    // Simulate the transfer from alice to bob
    _simulateTransferCall(smartObjectId, secondObjectId, itemsToTransfer);

    // Verify post-transfer state
    uint256[] memory postAliceItems = Inventory.getItems(smartObjectId);
    uint256[] memory postBobItems = Inventory.getItems(secondObjectId);

    // Alice should have half the items left (odd indices)
    assertEq(postAliceItems.length, testItemCount - transferCount);

    // Bob should have received the transferred items
    assertEq(postBobItems.length, transferCount);

    // Verify transferred items are in bob's inventory with correct quantities
    for (uint256 i = 0; i < transferCount; i++) {
      uint256 index = i * 2;
      uint256 objectId = testObjectIds[index];
      uint256 expectedQuantity = isSingleton[index] ? 1 : (index + 2);

      // Item should be removed from alice's inventory
      assertEq(InventoryItem.get(smartObjectId, objectId).exists, false);

      // Item should be in bob's inventory with correct quantity
      assertEq(InventoryItem.get(secondObjectId, objectId).exists, true);
      assertEq(InventoryItem.get(secondObjectId, objectId).quantity, expectedQuantity);

      // For singleton items, check ownership tracking
      if (isSingleton[index]) {
        assertEq(InventoryByItem.getInventoryObjectId(objectId), secondObjectId);
      }
    }

    // Verify remaining items in alice's inventory
    for (uint256 i = 0; i < transferCount; i++) {
      uint256 index = (i * 2) + 1; // Odd indices: 1, 3, 5, 7, 9
      uint256 objectId = testObjectIds[index];
      uint256 expectedQuantity = isSingleton[index] ? 1 : (index + 2);

      // Item should still be in alice's inventory with original quantity
      assertEq(InventoryItem.get(smartObjectId, objectId).exists, true);
      assertEq(InventoryItem.get(smartObjectId, objectId).quantity, expectedQuantity);

      // For singleton items, check ownership tracking
      if (isSingleton[index]) {
        assertEq(InventoryByItem.getInventoryObjectId(objectId), smartObjectId);
      }
    }

    // Calculate and validate final capacity usage
    uint256 expectedAliceCapacity = 0;
    uint256 expectedBobCapacity = 0;

    // Calculate Alice's capacity (odd indices)
    for (uint256 i = 0; i < transferCount; i++) {
      uint256 index = (i * 2) + 1; // Odd indices: 1, 3, 5, 7, 9...
      uint256 quantity = isSingleton[index] ? 1 : (index + 2);
      expectedAliceCapacity += volumes[index] * quantity;
    }

    // Calculate Bob's capacity (even indices)
    for (uint256 i = 0; i < transferCount; i++) {
      uint256 index = i * 2; // Even indices: 0, 2, 4, 6, 8...
      uint256 quantity = isSingleton[index] ? 1 : (index + 2);
      expectedBobCapacity += volumes[index] * quantity;
    }

    // Verify final capacity matches expected values
    assertEq(Inventory.getUsedCapacity(smartObjectId), expectedAliceCapacity, "Alice's inventory capacity incorrect");
    assertEq(Inventory.getUsedCapacity(secondObjectId), expectedBobCapacity, "Bob's inventory capacity incorrect");
  }

  // Helper function to simulate a proper system-to-system call
  function _simulateTransferCall(
    uint256 sourceInventoryId,
    uint256 targetInventoryId,
    InventoryItemParams[] memory transferItems
  ) internal {
    // Call the inventory system through our mock system to get callCount > 1
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callInventoryWithdraw.selector,
        sourceInventoryId,
        transferItems
      )
    );
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callInventoryDeposit.selector,
        targetInventoryId,
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
