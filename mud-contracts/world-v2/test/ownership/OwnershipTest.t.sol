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
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

// Local namespace tables
import { GlobalDeployableState, Inventory, Tenant, EntityRecord, InventoryItem, InventoryByItem, OwnershipByObject, CharactersByAccount, LocationData, EphemeralInventory, EphemeralInvItem, InventoryByEphemeral } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { GlobalDeployableState, Inventory, Tenant, EntityRecord, DeployableState, DeployableStateData, InventoryItemData, InventoryItem, InventoryByItem, OwnershipByObject, EphemeralInvCapacity, CharactersByAccount, LocationData, EphemeralInventory, EphemeralInvItem, InventoryByEphemeral } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock system to properly test system-to-system calls
contract MockOwnershipInteractSystem is System {
  function callAssignOwner(uint256 smartObjectId, address to) public {
    ownershipSystem.assignOwner(smartObjectId, to);
  }

  function callRemoveOwner(uint256 smartObjectId, address from) public {
    ownershipSystem.removeOwner(smartObjectId, from);
  }
}

contract OwnershipTest is MudTest {
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
  MockOwnershipInteractSystem mockSystem;
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
    bytes16 name = bytes16("MockOwnershipInt");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockOwnershipInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](9);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = inventorySystem.toResourceId();
    systemIds[6] = ephemeralInventorySystem.toResourceId();
    systemIds[7] = ownershipSystem.toResourceId();
    systemIds[8] = mockSystemId;

    entitySystem.registerClass(inventoryObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(inventoryObjectClassId, smartObjectId, alice);

    // Make sure deploy system is active
    GlobalDeployableState.setIsPaused(false);

    // Setup deployable state for inventory
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

    // Configure access control to allow the mock system to call ownership systems
    ResourceId ownershipSystemId = ownershipSystem.toResourceId();

    bytes4[2] memory ownershipFunctionSelectors = [
      OwnershipSystem.assignOwner.selector,
      OwnershipSystem.removeOwner.selector
    ];

    for (uint i = 0; i < ownershipFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystemId, ownershipFunctionSelectors[i], address(mockSystem), true);
    }

    vm.stopPrank();

    // Bring deployable online
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 10000);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_setUp() public {
    // check the assigned ownership values from the deployable that was created in setUp with alice as the intended owner
    // Verify the smart object is owned by Alice
    address fetchedOwner = ownershipSystem.owner(smartObjectId);
    assertEq(fetchedOwner, alice, "Smart object should be owned by Alice");

    assertEq(
      OwnershipByObject.get(smartObjectId),
      alice,
      "Smart object should be marked as owned by Alice in OwnershipByObject table"
    );
  }

  function test_assignOwner() public {
    // Test ascribing ownership to an account
    // Create a simple singleton object
    uint256 testObjectItemId = 7777;
    uint256 testObjectTypeId = 8888;
    uint256 newSmartObjectId = _calculateObjectId(testObjectTypeId, testObjectItemId, true);

    // Register a minimal class and instantiate the object
    vm.startPrank(deployer);
    uint256 newClassId = uint256(keccak256(abi.encodePacked(tenantId, testObjectTypeId)));

    // Create with minimal systems
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = ownershipSystem.toResourceId(); // required because of the scope enforced access control
    systemIds[2] = mockSystemId; // required because of the scope enforced access control

    entitySystem.registerClass(newClassId, systemIds);
    entitySystem.instantiate(newClassId, newSmartObjectId, alice);

    // Setup entity record to make it a singleton
    _setupEntityRecord(newSmartObjectId, testObjectTypeId, testObjectItemId, 100);
    vm.stopPrank();

    // Verify no assigned owner initially
    assertEq(OwnershipByObject.get(newSmartObjectId), address(0), "Smart object should initially have no owner");

    // Test non-existent object
    uint256 nonExistentObjectId = 99999;

    // turn off access enforcement to test the next revert case
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(
      ownershipSystem.toResourceId(),
      OwnershipSystem.assignOwner.selector,
      false
    );

    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_NonexistentObject.selector, nonExistentObjectId));
    ownershipSystem.assignOwner(nonExistentObjectId, alice);

    // turn access enforcement back on
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(ownershipSystem.toResourceId(), OwnershipSystem.assignOwner.selector, true);

    // Test invalid account (account without a character)
    address invalidAccount = address(0x123);

    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_InvalidAccount.selector, invalidAccount));
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newSmartObjectId, invalidAccount)
    );

    // Test non-singleton object (newClassId is the scoped non-singleton version of newSmartObjectId)
    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_InvalidSingleton.selector, newClassId));
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newClassId, alice)
    );

    // Check state before assigning
    address currentOwner = ownershipSystem.owner(newSmartObjectId);
    assertEq(currentOwner, address(0), "Smart object should initially have no owner");
    assertEq(OwnershipByObject.get(newSmartObjectId), address(0), "OwnershipByObject table should show no owner");

    // Successful assignment
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newSmartObjectId, alice)
    );

    // Check the owner after assigning
    address ownerAfterAssign = ownershipSystem.owner(newSmartObjectId);
    assertEq(ownerAfterAssign, alice, "Smart object should now be owned by Alice");
    assertEq(OwnershipByObject.get(newSmartObjectId), alice, "OwnershipByObject table should show Alice as owner");

    // Verify the object cannot be re-assigned directly to another account
    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_AlreadyOwned.selector, newSmartObjectId, alice));
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newSmartObjectId, bob)
    );
    vm.stopPrank();
  }

  function test_removeOwner() public {
    // Create a simple singleton object for testing
    uint256 testObjectItemId = 7777;
    uint256 testObjectTypeId = 8888;
    uint256 newSmartObjectId = _calculateObjectId(testObjectTypeId, testObjectItemId, true);

    // Register a minimal class and instantiate the object
    vm.startPrank(deployer);
    uint256 newClassId = uint256(keccak256(abi.encodePacked(tenantId, testObjectTypeId)));

    // Create with minimal systems
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = ownershipSystem.toResourceId(); // required because of the scope enforced access control
    systemIds[2] = mockSystemId; // required because of the scope enforced access control

    entitySystem.registerClass(newClassId, systemIds);
    entitySystem.instantiate(newClassId, newSmartObjectId, alice);

    // Setup entity record to make it a singleton
    _setupEntityRecord(newSmartObjectId, testObjectTypeId, testObjectItemId, 100);

    // assign ownership to alice
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newSmartObjectId, alice)
    );
    vm.stopPrank();

    // Verify initial state - alice should own the object
    assertEq(ownershipSystem.owner(newSmartObjectId), alice, "Smart object should be owned by Alice initially");
    assertEq(OwnershipByObject.get(newSmartObjectId), alice, "OwnershipByObject table should show Alice as owner");

    // turn off access enforcement to test the next revert case
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(
      ownershipSystem.toResourceId(),
      OwnershipSystem.removeOwner.selector,
      false
    );

    // Test removing a non-existent object
    uint256 nonExistentObjectId = 99999;
    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_NonexistentObject.selector, nonExistentObjectId));
    ownershipSystem.removeOwner(nonExistentObjectId, alice);

    // turn access enforcement back on
    vm.prank(deployer);
    accessConfigSystem.setAccessEnforcement(ownershipSystem.toResourceId(), OwnershipSystem.removeOwner.selector, true);

    // Try removing a non-singleton object (newClassId is the scoped non-singleton version of newSmartObjectId)
    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_InvalidSingleton.selector, newClassId));
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callRemoveOwner.selector, newClassId, alice)
    );

    // Try to remove with wrong owner
    vm.expectRevert(abi.encodeWithSelector(OwnershipSystem.Ownership_InvalidOwner.selector, newSmartObjectId, bob));
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callRemoveOwner.selector, newSmartObjectId, bob)
    );

    // Successful case: remove ownership properly
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callRemoveOwner.selector, newSmartObjectId, alice)
    );

    // Verify the state after removement
    assertEq(ownershipSystem.owner(newSmartObjectId), address(0), "Smart object should have no owner after removal");
    assertEq(OwnershipByObject.get(newSmartObjectId), address(0), "OwnershipByObject table should show no owner");

    // After removement, we should be able to assign ownership again
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, newSmartObjectId, bob)
    );
    assertEq(ownershipSystem.owner(newSmartObjectId), bob, "Smart object should be owned by Bob after re-assigning");
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

  // Helper function to simulate a proper system-to-system call to assignOwner
  function _simulateAssignOwnerCall(uint256 assignOwnerObjectId, address to) internal {
    // Call the ownership system through our mock system to get callCount > 1
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callAssignOwner.selector, assignOwnerObjectId, to)
    );
  }

  // Helper function to simulate a proper system-to-system call to removeOwner
  function _simulateRemoveOwnerCall(uint256 removeObjectId, address from) internal {
    // Call the ownership system through our mock system to get callCount > 1
    world.call(
      mockSystemId,
      abi.encodeWithSelector(MockOwnershipInteractSystem.callRemoveOwner.selector, removeObjectId, from)
    );
  }
}
