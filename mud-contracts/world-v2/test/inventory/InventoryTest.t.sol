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
  EphemeralInvCapacity,
  CharactersByAccount
} from "../../src/namespaces/evefrontier/codegen/index.sol";
import { State } from "../../src/codegen/common.sol";

// Local namespace systems
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { InventorySystem } from "../../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams, CreateInventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";

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
  uint256 constant ITEM2_ID = 4236;
  uint256 constant ITEM3_ID = 4237;
  uint256 constant TRANSFER_ITEM_ID = 4238;
  uint256 constant ITEM_TYPE_ID = 1000;
  uint256 constant ITEM_TYPE_ID_NON_SINGLETON = 1001; // Non-singleton item type
  uint256 constant ITEM_VOLUME = 100;

  // Test addresses
  address deployer;
  address alice;
  address bob;
  
  // Mock system address
  MockInventoryInteractSystem mockSystem;
  ResourceId mockSystemId;

  // Define singleton and non-singleton items in your constants section
  bool constant ITEM1_IS_SINGLETON = true;
  bool constant ITEM2_IS_SINGLETON = true;
  bool constant ITEM3_IS_NON_SINGLETON = false; // Making this a non-singleton item
  bool constant TRANSFER_ITEM_IS_NON_SINGLETON = false;

  uint256 item1ObjectId;
  uint256 item2ObjectId;
  uint256 item3ObjectId;
  uint256 transferItemObjectId;

  // Add these constants to your test file 
  uint256 constant CREATE_SINGLETON_ITEM_ID = 9001;
  uint256 constant CREATE_NON_SINGLETON_ITEM_ID = 0;
  uint256 constant CREATE_SINGLETON_ITEM_TYPE_ID = 9000;
  uint256 constant CREATE_NON_SINGLETON_ITEM_TYPE_ID = 9090;
  bool constant CREATE_SINGLETON_IS_SINGLETON = true;
  bool constant CREATE_NON_SINGLETON_IS_SINGLETON = false;

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
    
    vm.startPrank(deployer);

    // Mock smart character data for alice and bob
    CharactersByAccount.set(alice, 1);
    CharactersByAccount.set(bob, 2);
    
    // Setup tenant
    tenantId = keccak256(abi.encodePacked("TEST"));
    
    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_ID, SMART_OBJECT_TYPE_ID, true);
    secondObjectId = _calculateObjectId(SECOND_OBJECT_ID, SMART_OBJECT_TYPE_ID, true);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("mockInvInteract"); 
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);
    
    // Deploy and register the mock system
    mockSystem = new MockInventoryInteractSystem();
    
    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);
    
    // Register class and setup smart object state
    uint256 inventoryObjectClassId = uint256(keccak256(abi.encodePacked(SMART_OBJECT_TYPE_ID)));
    ResourceId[] memory systemIds = new ResourceId[](2);
    systemIds[0] = inventorySystem.toResourceId();
    systemIds[1] = mockSystemId;

    entitySystem.registerClass(inventoryObjectClassId, systemIds);
    entitySystem.instantiate(inventoryObjectClassId, smartObjectId, alice);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_ID, SMART_OBJECT_TYPE_ID, 10);
    ownershipSystem.ascribeToAccount(smartObjectId, alice);
    entitySystem.instantiate(inventoryObjectClassId, secondObjectId, bob);
    _setupEntityRecord(secondObjectId, SECOND_OBJECT_ID, SMART_OBJECT_TYPE_ID, 10);
    ownershipSystem.ascribeToAccount(secondObjectId, bob);

    // Make sure deploy system is active
    GlobalDeployableState.setIsPaused(true); // Use true for "active" (counterintuitive, but matches the contract)
    
    // Setup deployable state for first inventory
    DeployableState.set(
      smartObjectId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: State.ANCHORED,
        currentState: State.ONLINE,
        isValid: true,
        anchoredAt: block.timestamp,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
    
    // Setup deployable state for second inventory
    DeployableState.set(
      secondObjectId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: State.ANCHORED,
        currentState: State.ONLINE,
        isValid: true,
        anchoredAt: block.timestamp,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
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
    item1ObjectId = _calculateObjectId(ITEM1_ID, ITEM_TYPE_ID, ITEM1_IS_SINGLETON);
    item2ObjectId = _calculateObjectId(ITEM2_ID, ITEM_TYPE_ID, ITEM2_IS_SINGLETON);
    item3ObjectId = _calculateObjectId(ITEM3_ID, ITEM_TYPE_ID, ITEM3_IS_NON_SINGLETON);
    transferItemObjectId = _calculateObjectId(TRANSFER_ITEM_ID, ITEM_TYPE_ID, TRANSFER_ITEM_IS_NON_SINGLETON);
    
    // Set up item records with the correct parameters
    _setupEntityRecord(item1ObjectId, ITEM1_ID, ITEM_TYPE_ID, ITEM_VOLUME);
    _setupEntityRecord(item2ObjectId, ITEM2_ID, ITEM_TYPE_ID, ITEM_VOLUME);
    _setupEntityRecord(item3ObjectId, ITEM3_ID, ITEM_TYPE_ID_NON_SINGLETON, ITEM_VOLUME);
    _setupEntityRecord(transferItemObjectId, TRANSFER_ITEM_ID, ITEM_TYPE_ID_NON_SINGLETON, ITEM_VOLUME);
     vm.stopPrank();
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
    uint256 singletonObjectId = _calculateObjectId(CREATE_SINGLETON_ITEM_ID, CREATE_SINGLETON_ITEM_TYPE_ID, true);
    uint256 nonSingletonObjectId = _calculateObjectId(CREATE_NON_SINGLETON_ITEM_ID, CREATE_NON_SINGLETON_ITEM_TYPE_ID, false);

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
    vm.expectRevert(abi.encodeWithSelector(InventorySystem.Inventory_InvalidTenantId.selector, wrongTenantObjectId, wrongTenantId));
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
    
    vm.expectRevert(abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, wrongSingletonObjectId));
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
    
    vm.expectRevert(abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, singletonObjectId, 2));
    inventorySystem.createAndDepositInventory(smartObjectId, invalidQuantityItems);
    
    // Test for non-singleton item with invalid object ID
    uint256 wrongNonSingletonObjectId = uint256(0x789); // Not matching hash of typeId
    
    CreateInventoryItemParams[] memory invalidNonSingletonObjectItems = new CreateInventoryItemParams[](1);
    invalidNonSingletonObjectItems[0] = CreateInventoryItemParams({
      smartObjectId: wrongNonSingletonObjectId,
      tenantId: bytes32(0),
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0, // For non-singleton items, itemId is zero
      quantity: 9,
      volume: ITEM_VOLUME
    });
    
    vm.expectRevert(abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemObjectId.selector, wrongNonSingletonObjectId));
    inventorySystem.createAndDepositInventory(smartObjectId, invalidNonSingletonObjectItems);
    
    // Test for non-singleton item with invalid quantity
    CreateInventoryItemParams[] memory invalidNonSingletonQuantityItems = new CreateInventoryItemParams[](1);
    invalidNonSingletonQuantityItems[0] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: bytes32(0),
      typeId: CREATE_NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0,
      quantity: 0, // Should be > 0 for non-singleton items
      volume: ITEM_VOLUME
    });
    
    vm.expectRevert(abi.encodeWithSelector(InventorySystem.Inventory_InvalidItemDepositQuantity.selector, nonSingletonObjectId, 0));
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
      tenantId: bytes32(0), // For non-singleton items, tenantId is zero
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
    
    // Create and deposit items
    vm.startPrank(alice, deployer);
    inventorySystem.createAndDepositInventory(smartObjectId, items);
    vm.stopPrank();

    // Verify final state
    assertEq(Inventory.getItems(smartObjectId).length, 2);
    assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 10);
    assertEq(EntityRecord.getExists(singletonObjectId), true);
    assertEq(EntityRecord.getExists(nonSingletonObjectId), true);
  }

  // Test depositing inventory items
  function test_depositInventory() public {
    // Prepare item params for deposit
    InventoryItemParams[] memory items = new InventoryItemParams[](2);
    
    items[0] = InventoryItemParams({
      smartObjectId: item1ObjectId,
      quantity: 1
    });
    
    items[1] = InventoryItemParams({
      smartObjectId: item2ObjectId,
      quantity: 2
    });
    
    // Test revert: game is paused
    vm.startPrank(deployer); // Use deployer for GlobalDeployableState access
    GlobalDeployableState.setIsPaused(false);
    vm.stopPrank();
    
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        DeployableSystem.Deployable_StateTransitionPaused.selector
      )
    );
    inventorySystem.depositInventory(smartObjectId, items);
    vm.stopPrank();
    
    vm.startPrank(deployer); // Use deployer for GlobalDeployableState access
    GlobalDeployableState.setIsPaused(true);
    vm.stopPrank();
    
    // Test revert: incorrect state
    vm.startPrank(deployer); // Use deployer for DeployableState access
    DeployableState.setCurrentState(smartObjectId, State.ANCHORED);
    vm.stopPrank();
    
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        DeployableSystem.Deployable_IncorrectState.selector,
        smartObjectId,
        State.ANCHORED
      )
    );
    inventorySystem.depositInventory(smartObjectId, items);
    vm.stopPrank();
    
    // Reset state to ONLINE
    vm.startPrank(deployer); // Use deployer for DeployableState access
    DeployableState.setCurrentState(smartObjectId, State.ONLINE);
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
    
    // // Test direct call behavior (callCount == 1)
    // // This verifies that ascribeToInventory is called on direct calls
    // vm.startPrank(alice, deployer);
    
    // // Check initial ownership state
    // assertEq(InventoryByItem.get(ITEM1_ID), 0); // Initially not in any inventory
    
    // // Call depositInventory directly
    // inventorySystem.depositInventory(smartObjectId, items);
    
    // // Verify ownership was ascribed to inventory
    // assertEq(InventoryByItem.get(ITEM1_ID), smartObjectId);
    // assertEq(InventoryByItem.get(ITEM2_ID), smartObjectId);
    // vm.stopPrank();
    
    // // Test system-to-system call behavior (callCount > 1)
    // // First deposit the transfer item into the first inventory
    // InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    // transferItems[0] = InventoryItemParams({
    //   smartObjectId: TRANSFER_ITEM_ID,
    //   quantity: 10
    // });
    
    // vm.startPrank(alice, deployer);
    // inventorySystem.depositInventory(smartObjectId, transferItems);
    // assertEq(InventoryByItem.get(TRANSFER_ITEM_ID), smartObjectId); // Verify initial inventory
    // // quantity should be 10
    // assertEq(InventoryItem.get(smartObjectId, TRANSFER_ITEM_ID).quantity, 10);
    // vm.stopPrank();
    
    // // Now simulate a proper system-to-system call using our mock system
    // _simulateSystemToSystemTransfer(TRANSFER_ITEM_ID, secondObjectId, 5);
    
    // // Verify the item was transferred between inventories
    // assertEq(InventoryByItem.get(TRANSFER_ITEM_ID), secondObjectId);
    // // quantity should be 5 and 5
    // assertEq(InventoryItem.get(smartObjectId, TRANSFER_ITEM_ID).quantity, 5);
    // assertEq(InventoryItem.get(secondObjectId, TRANSFER_ITEM_ID).quantity, 5);
    
    // // Check initial state before depositing more items
    // assertEq(Inventory.getItems(smartObjectId).length, 2);
    // assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 3); // 1 + 2 items
    
    // // Deposit more items
    // vm.startPrank(alice, deployer);
    // inventorySystem.depositInventory(smartObjectId, items);
    // vm.stopPrank();

    // // Verify final state
    // assertEq(Inventory.getItems(smartObjectId).length, 2);
    // assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 6); // 2 + 4 items
    
    // // Check item details
    // InventoryItemData memory item1Data = InventoryItem.get(smartObjectId, ITEM1_ID);
    // InventoryItemData memory item2Data = InventoryItem.get(smartObjectId, ITEM2_ID);
    
    // assertEq(item1Data.quantity, 2);
    // assertEq(item2Data.quantity, 4);
    // assertEq(item1Data.index, 0);
    // assertEq(item2Data.index, 1);
    
    // // Test revert: insufficient capacity
    // items[0].quantity = 10; // Would exceed capacity
    
    // vm.startPrank(alice, deployer);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     InventorySystem.Inventory_InsufficientCapacity.selector,
    //     "InventorySystem: insufficient capacity",
    //     1000,
    //     ITEM_VOLUME * 14 // 2 + 4 + 10 - 2
    //   )
    // );
    // inventorySystem.depositInventory(smartObjectId, items);
    // vm.stopPrank();
    
    // // Test increasing existing item quantity
    // items[0].quantity = 1; // Set back to 1 to test increasing
    
    // vm.startPrank(alice, deployer);
    // inventorySystem.depositInventory(smartObjectId, items);
    // vm.stopPrank();
    
    // // Verify quantity increased
    // item1Data = InventoryItem.get(smartObjectId, ITEM1_ID);
    // item2Data = InventoryItem.get(smartObjectId, ITEM2_ID);
    
    // assertEq(item1Data.quantity, 3); // Was 2, now 3
    // assertEq(item2Data.quantity, 6); // Was 4, now 6
    // assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 9); // 3 + 6 items
    // assertEq(Inventory.getItems(smartObjectId).length, 2); // Still 2 unique items
  }

  // Test withdrawing inventory items
  function test_withdrawInventory() public {
    // // First set up inventory with items
    // test_depositInventory();
    
    // // We should now have 2 items with quantities 2 and 4, total capacity used = 600
    // uint256 initialCapacityUsed = Inventory.getUsedCapacity(smartObjectId);
    // assertEq(initialCapacityUsed, ITEM_VOLUME * 6);
    
    // // Create withdrawal params
    // InventoryItemParams[] memory items = new InventoryItemParams[](2);
    
    // items[0] = InventoryItemParams({
    //   smartObjectId: ITEM1_ID,
    //   quantity: 1 // Withdraw 1 of 2
    // });
    
    // items[1] = InventoryItemParams({
    //   smartObjectId: ITEM2_ID,
    //   quantity: 4 // Withdraw all 4
    // });
    
    // // Test revert: game is paused
    // GlobalDeployableState.setIsPaused(false);
    // vm.startPrank(alice);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     DeployableSystem.Deployable_StateTransitionPaused.selector
    //   )
    // );
    // inventorySystem.withdrawInventory(smartObjectId, items);
    // vm.stopPrank();
    // GlobalDeployableState.setIsPaused(true);
    
    // // Test revert: incorrect state
    // DeployableState.setCurrentState(smartObjectId, State.ANCHORED);
    // vm.startPrank(alice);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     DeployableSystem.Deployable_IncorrectState.selector,
    //     smartObjectId,
    //     State.ANCHORED
    //   )
    // );
    // inventorySystem.withdrawInventory(smartObjectId, items);
    // vm.stopPrank();
    
    // // Reset state to ONLINE
    // DeployableState.setCurrentState(smartObjectId, State.ONLINE);
    
    // // Test revert: invalid withdrawal quantity
    // InventoryItemParams[] memory invalidItems = new InventoryItemParams[](1);
    // invalidItems[0] = InventoryItemParams({
    //   smartObjectId: ITEM1_ID,
    //   quantity: 10 // Trying to withdraw more than available
    // });
    
    // vm.startPrank(alice);
    // vm.expectRevert(
    //   abi.encodeWithSelector(
    //     InventorySystem.Inventory_InvalidItemWithdrawalQuantity.selector,
    //     "InventorySystem: invalid quantity",
    //     ITEM1_ID,
    //     10,
    //     2 // We have 2 available
    //   )
    // );
    // inventorySystem.withdrawInventory(smartObjectId, invalidItems);
    // vm.stopPrank();
    
    // // Now perform valid withdrawal
    // vm.startPrank(alice);
    // inventorySystem.withdrawInventory(smartObjectId, items);
    // vm.stopPrank();
    
    // // Verify final state
    // InventoryItemData memory item1Data = InventoryItem.get(smartObjectId, ITEM1_ID);
    // assertEq(item1Data.quantity, 1); // Was 2, now 1
    
    // // Item 2 should be completely removed
    // uint256[] memory remainingItems = Inventory.getItems(smartObjectId);
    // assertEq(remainingItems.length, 1); // Only item1 should remain
    // assertEq(remainingItems[0], ITEM1_ID);
    
    // // Check capacity
    // uint256 finalCapacityUsed = Inventory.getUsedCapacity(smartObjectId);
    // assertEq(finalCapacityUsed, ITEM_VOLUME); // Only 1 item of volume 100 left
  }

  // Test complete removal of all items
  function test_withdrawAllItems() public {
    // // First set up inventory with items
    // test_depositInventory();
    
    // // We should now have 2 items with quantities 2 and 4
    // // Create withdrawal params to remove all
    // InventoryItemParams[] memory items = new InventoryItemParams[](2);
    
    // items[0] = InventoryItemParams({
    //   smartObjectId: ITEM1_ID,
    //   quantity: 2 // Withdraw all 2
    // });
    
    // items[1] = InventoryItemParams({
    //   smartObjectId: ITEM2_ID,
    //   quantity: 4 // Withdraw all 4
    // });
    
    // // Perform withdrawal
    // vm.startPrank(alice);
    // inventorySystem.withdrawInventory(smartObjectId, items);
    // vm.stopPrank();
    
    // // Verify final state
    // uint256[] memory remainingItems = Inventory.getItems(smartObjectId);
    // assertEq(remainingItems.length, 0); // No items should remain
    // assertEq(Inventory.getUsedCapacity(smartObjectId), 0); // No capacity used
  }

  // Test complex deposit and withdraw scenario
  function test_depositAndWithdrawMultipleItems() public {
  //   // Setup capacity
  //   uint256 capacity = 2000;
  //   vm.startPrank(alice);
  //   inventorySystem.setCapacity(smartObjectId, capacity);
  //   vm.stopPrank();
    
  //   // Deposit items in batches
  //   InventoryItemParams[] memory deposit1 = new InventoryItemParams[](2);
  //   deposit1[0] = InventoryItemParams({
  //     smartObjectId: ITEM1_ID,
  //     quantity: 3
  //   });
  //   deposit1[1] = InventoryItemParams({
  //     smartObjectId: ITEM2_ID,
  //     quantity: 2
  //   });
    
  //   vm.startPrank(alice);
  //   inventorySystem.depositInventory(smartObjectId, deposit1);
  //   vm.stopPrank();
    
  //   // Verify first deposit
  //   assertEq(Inventory.getItems(smartObjectId).length, 2);
  //   assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 5);
    
  //   // Deposit more items
  //   InventoryItemParams[] memory deposit2 = new InventoryItemParams[](2);
  //   deposit2[0] = InventoryItemParams({
  //     smartObjectId: ITEM2_ID,
  //     quantity: 1
  //   });
  //   deposit2[1] = InventoryItemParams({
  //     smartObjectId: ITEM3_ID,
  //     quantity: 4
  //   });
    
  //   vm.startPrank(alice);
  //   inventorySystem.depositInventory(smartObjectId, deposit2);
  //   vm.stopPrank();
    
  //   // Verify second deposit
  //   assertEq(Inventory.getItems(smartObjectId).length, 3);
  //   assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 10); // 3 + 3 + 4
    
  //   // Check individual items
  //   InventoryItemData memory item1Data = InventoryItem.get(smartObjectId, ITEM1_ID);
  //   InventoryItemData memory item2Data = InventoryItem.get(smartObjectId, ITEM2_ID);
  //   InventoryItemData memory item3Data = InventoryItem.get(smartObjectId, ITEM3_ID);
    
  //   assertEq(item1Data.quantity, 3);
  //   assertEq(item2Data.quantity, 3);
  //   assertEq(item3Data.quantity, 4);
    
  //   // Withdraw partial amounts
  //   InventoryItemParams[] memory withdraw1 = new InventoryItemParams[](2);
  //   withdraw1[0] = InventoryItemParams({
  //     smartObjectId: ITEM1_ID,
  //     quantity: 2
  //   });
  //   withdraw1[1] = InventoryItemParams({
  //     smartObjectId: ITEM3_ID,
  //     quantity: 3
  //   });
    
  //   vm.startPrank(alice);
  //   inventorySystem.withdrawInventory(smartObjectId, withdraw1);
  //   vm.stopPrank();
    
  //   // Verify after partial withdrawal
  //   item1Data = InventoryItem.get(smartObjectId, ITEM1_ID);
  //   item3Data = InventoryItem.get(smartObjectId, ITEM3_ID);
    
  //   assertEq(item1Data.quantity, 1);
  //   assertEq(item3Data.quantity, 1);
  //   assertEq(Inventory.getUsedCapacity(smartObjectId), ITEM_VOLUME * 5); // 1 + 3 + 1
    
  //   // Final withdrawal of everything
  //   InventoryItemParams[] memory withdraw2 = new InventoryItemParams[](3);
  //   withdraw2[0] = InventoryItemParams({
  //     smartObjectId: ITEM1_ID,
  //     quantity: 1
  //   });
  //   withdraw2[1] = InventoryItemParams({
  //     smartObjectId: ITEM2_ID,
  //     quantity: 3
  //   });
  //   withdraw2[2] = InventoryItemParams({
  //     smartObjectId: ITEM3_ID,
  //     quantity: 1
  //   });
    
  //   vm.startPrank(alice);
  //   inventorySystem.withdrawInventory(smartObjectId, withdraw2);
  //   vm.stopPrank();
    
  //   // Verify complete withdrawal
  //   assertEq(Inventory.getItems(smartObjectId).length, 0);
  //   assertEq(Inventory.getUsedCapacity(smartObjectId), 0);
  }

  // Helper function to simulate a proper system-to-system call
  function _simulateSystemToSystemTransfer(
    uint256 itemId,
    uint256 toInventoryId,
    uint256 quantity
  ) internal {
    // Create transfer item params
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({
      smartObjectId: itemId,
      quantity: quantity
    });
    
    // Call the inventory system through our mock system to get callCount > 1
    vm.startPrank(bob); // Bob is owner of the second inventory
    world.call(
      mockSystemId,
      abi.encodeWithSelector(
        MockInventoryInteractSystem.callInventoryDeposit.selector,
        toInventoryId,
        transferItems
      )
    );
    vm.stopPrank();
  }

  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
    
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

  // Add a helper function to calculate itemObjectId
  function _calculateObjectId(uint256 itemId, uint256 typeId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(typeId)));
    }
  }
}
