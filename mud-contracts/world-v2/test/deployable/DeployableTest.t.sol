// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

// Smart Object Framework imports
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { TagParams, ResourceRelationValue, TAG_TYPE_RESOURCE_RELATION } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

// Local namespace tables
import { GlobalDeployableState, Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, CharactersByAccount, LocationData, EphemeralInventory, SmartAssembly, Fuel, FuelData, Location, LocationData } from "../../src/namespaces/evefrontier/codegen/index.sol";

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
import { smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

// Create a mock system to properly test system-to-system calls
contract MockDeployableInteractSystem is System {
  function callCreateAndAnchor(CreateAndAnchorParams memory params) public {
    deployableSystem.createAndAnchor(params);
  }

  function callCreateDeployable(
    uint256 smartObjectId,
    address owner,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionInterval,
    uint256 fuelMaxCapacity
  ) public {
    deployableSystem.createDeployable(smartObjectId, owner, fuelUnitVolume, fuelConsumptionInterval, fuelMaxCapacity);
  }

  function callDestroyDeployable(uint256 smartObjectId) public {
    deployableSystem.destroyDeployable(smartObjectId);
  }

  function callAnchor(uint256 smartObjectId, address owner, LocationData memory location) public {
    deployableSystem.anchor(smartObjectId, owner, location);
  }

  function callUnanchor(uint256 smartObjectId) public {
    deployableSystem.unanchor(smartObjectId);
  }

  function callBringOnline(uint256 smartObjectId) public {
    deployableSystem.bringOnline(smartObjectId);
  }

  function callBringOffline(uint256 smartObjectId) public {
    deployableSystem.bringOffline(smartObjectId);
  }

  function callGlobalPause() public {
    deployableSystem.globalPause();
  }

  function callGlobalResume() public {
    deployableSystem.globalResume();
  }
}

contract DeployableTest is MudTest {
  using ResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 deployableObjectClassId;
  uint256 smartObjectId;
  bytes32 tenantId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;

  uint256 smartGate1Id;
  uint256 smartGate2Id;

  uint256 constant GATE_1_ID = 1236;
  uint256 constant GATE_2_ID = 1237;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  // Mock system address
  MockDeployableInteractSystem mockSystem;
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

    // Setup smart object IDs
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

    smartGate1Id = _calculateObjectId(EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()), GATE_1_ID, true);
    smartGate2Id = _calculateObjectId(EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()), GATE_2_ID, true);

    // Register class and setup smart object state
    deployableObjectClassId = _calculateObjectId(SMART_OBJECT_TYPE_ID, 0, false);

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockDeployableIn");
    mockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    mockSystem = new MockDeployableInteractSystem();

    // Register the system with the world
    world.registerSystem(mockSystemId, mockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = ownershipSystem.toResourceId();
    systemIds[6] = mockSystemId;

    entitySystem.registerClass(deployableObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(deployableObjectClassId, smartObjectId, alice);

    // Make sure deploy system is active
    GlobalDeployableState.setIsPaused(false);

    // Configure access control to allow the mock system to call ownership system
    ResourceId deployableSystemId = deployableSystem.toResourceId();
    bytes4[9] memory deployableFunctionSelectors = [
      DeployableSystem.createAndAnchor.selector,
      DeployableSystem.createDeployable.selector,
      DeployableSystem.destroyDeployable.selector,
      DeployableSystem.anchor.selector,
      DeployableSystem.unanchor.selector,
      DeployableSystem.bringOnline.selector,
      DeployableSystem.bringOffline.selector,
      DeployableSystem.globalPause.selector,
      DeployableSystem.globalResume.selector
    ];

    for (uint i = 0; i < deployableFunctionSelectors.length; i++) {
      CallAccess.set(deployableSystemId, deployableFunctionSelectors[i], address(mockSystem), true);
    }
    vm.stopPrank();
  }

  function test_CreateAndAnchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Verify initial states
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.NULL), "Initial state should be NULL");
    assertFalse(DeployableState.getIsValid(smartObjectId), "Deployable should not be valid initially");

    // Define expected assembly type
    string memory expectedAssemblyType = "SSU";

    // Setup deployable state for inventory
    vm.prank(alice, deployer);
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        expectedAssemblyType,
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      )
    );

    // Verify smart assembly was created correctly
    assertEq(SmartAssembly.get(smartObjectId), expectedAssemblyType, "Assembly type should match");

    // Verify entity record was created
    EntityRecordData memory entityRecord = EntityRecord.get(smartObjectId);
    assertEq(entityRecord.exists, true, "Entity record should exist");
    assertEq(entityRecord.tenantId, tenantId, "Tenant ID should match");
    assertEq(entityRecord.itemId, SMART_OBJECT_ID, "Item ID should match");
    assertEq(entityRecord.typeId, SMART_OBJECT_TYPE_ID, "Type ID should match");

    // Verify deployable state
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.ANCHORED), "State should be ANCHORED");
    assertEq(
      uint8(DeployableState.getPreviousState(smartObjectId)),
      uint8(State.UNANCHORED),
      "Previous state should be UNANCHORED"
    );
    assertTrue(DeployableState.getIsValid(smartObjectId), "Deployable should be valid");

    // Verify fuel configuration
    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuel.fuelUnitVolume, fuelUnitVolume, "Fuel unit volume should be set correctly");
    assertEq(
      fuel.fuelConsumptionIntervalInSeconds,
      fuelConsumptionIntervalInSeconds,
      "Fuel consumption interval should be set correctly"
    );
    assertEq(fuel.fuelMaxCapacity, fuelMaxCapacity, "Fuel max capacity should be set correctly");

    // Verify ownership
    address owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, alice, "Owner should be alice");

    // Verify location data
    LocationData memory location = Location.get(smartObjectId);
    assertEq(location.solarSystemId, 1, "Solar system ID should match");
    assertEq(location.x, 1000, "X coordinate should match");
    assertEq(location.y, 1001, "Y coordinate should match");
    assertEq(location.z, 1002, "Z coordinate should match");

    // // Verify inventory was initialized
    // assertEq(Inventory.getVersion(smartObjectId), 1, "Inventory version should be 1");
  }

  function test_CreateDeployable(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Setup entity record for the smart object
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();

    // Verify initial states
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.NULL), "Initial state should be NULL");
    assertFalse(DeployableState.getIsValid(smartObjectId), "Deployable should not be valid initially");

    // Test revert cases in order of failure

    // Invalid fuel unit volume min case
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelUnitVolume.selector,
        smartObjectId,
        0,
        1,
        uint256(type(uint128).max)
      )
    );
    deployableSystem.createDeployable(smartObjectId, alice, 0, fuelConsumptionIntervalInSeconds, fuelMaxCapacity); // min amount is 1

    // Invalid fuel unit volume max case
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelUnitVolume.selector,
        smartObjectId,
        uint256(type(uint128).max) + 1,
        1,
        uint256(type(uint128).max)
      )
    );
    deployableSystem.createDeployable(
      smartObjectId,
      alice,
      uint256(type(uint128).max) + 1,
      fuelConsumptionIntervalInSeconds,
      type(uint256).max
    ); // max amount is type(uint128).max

    // Invalid fuel consumption interval min case
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_InvalidFuelConsumptionInterval.selector, smartObjectId)
    );
    deployableSystem.createDeployable(smartObjectId, alice, fuelUnitVolume, 0, fuelMaxCapacity); // max amount is 1000000

    // Invalid fuel consumption interval max case
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelConsumptionInterval.selector,
        smartObjectId,
        type(uint256).max,
        1,
        type(uint256).max / ONE_UNIT_IN_WEI
      )
    );
    deployableSystem.createDeployable(smartObjectId, alice, fuelUnitVolume, type(uint256).max, fuelMaxCapacity); // max amount is type(uint256).max / ONE_UNIT_IN_WEI

    // Invalid fuel max capacity min case
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelMaxCapacity.selector,
        smartObjectId,
        100000000,
        100000001,
        type(uint256).max
      )
    );
    deployableSystem.createDeployable(smartObjectId, alice, 100000000, fuelConsumptionIntervalInSeconds, 100000000); // max amount is 1000000

    // Case 2: Invalid character (owner must have a character ID)
    address nonCharacter = address(0x1234);
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(
        DeployableSystem.Deployable_InvalidObjectOwner.selector,
        "SmartDeployableSystem: Smart Object owner is not a valid Smart Character",
        nonCharacter,
        smartObjectId
      )
    );
    deployableSystem.createDeployable(
      smartObjectId,
      nonCharacter,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000

    // Successful case
    vm.prank(alice, deployer);
    deployableSystem.createDeployable(
      smartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000

    // Verify the state after successful creation

    // Check deployable state
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.UNANCHORED),
      "State should be UNANCHORED"
    );
    assertEq(
      uint8(DeployableState.getPreviousState(smartObjectId)),
      uint8(State.NULL),
      "Previous state should be NULL"
    );
    assertFalse(DeployableState.getIsValid(smartObjectId), "Deployable should not be valid yet");

    // Check ownership
    address owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, alice, "Owner should be alice");

    // Check fuel setup
    FuelData memory fuel = Fuel.get(smartObjectId);
    assertEq(fuel.fuelUnitVolume, fuelUnitVolume, "Fuel unit volume should be set correctly");
    assertEq(
      fuel.fuelConsumptionIntervalInSeconds,
      fuelConsumptionIntervalInSeconds,
      "Fuel consumption interval should be set correctly"
    );
    assertEq(fuel.fuelMaxCapacity, fuelMaxCapacity, "Fuel max capacity should be set correctly");
    assertEq(fuel.fuelAmount, 0, "Initial fuel amount should be zero");

    // Creating deployable when state is not NULL should revert
    // Current state after first creation is UNANCHORED
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    deployableSystem.createDeployable(
      smartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000
  }

  function test_DestroyDeployable() public {
    // Try to destroy a deployable that's not in ANCHORED or ONLINE state
    // Create a deployable (puts it in UNANCHORED state)
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();
    vm.prank(alice, deployer);
    deployableSystem.createDeployable(smartObjectId, alice, 100, 60, 100000000); // max amount is 1000000

    vm.startPrank(deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    deployableSystem.destroyDeployable(smartObjectId);
    vm.stopPrank();

    // ANCHOR the deployable
    vm.prank(alice, deployer);
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 }));

    // Verify the initial state before destruction
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.ANCHORED),
      "Initial state should be ANCHORED"
    );
    assertTrue(DeployableState.getIsValid(smartObjectId), "Deployable should be valid initially");
    assertEq(ownershipSystem.owner(smartObjectId), alice, "Owner should be alice");
    // uint256 inventoryVersionBefore = Inventory.getVersion(smartObjectId);

    // Test successful case: Destroy the ANCHORED deployable
    vm.prank(deployer);
    deployableSystem.destroyDeployable(smartObjectId);

    // Verify the state after destruction
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.DESTROYED),
      "State should be DESTROYED"
    );
    assertEq(
      uint8(DeployableState.getPreviousState(smartObjectId)),
      uint8(State.ANCHORED),
      "Previous state should be ANCHORED"
    );

    assertEq(ownershipSystem.owner(smartObjectId), address(0), "Owner should be removed");
  }

  function test_Anchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Test revert case: Attempt to anchor when state is not UNANCHORED
    // First, create and anchor a deployable
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();
    vm.startPrank(alice, deployer);
    deployableSystem.createDeployable(
      smartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000

    // Verify it's in UNANCHORED state
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.UNANCHORED),
      "State should be UNANCHORED"
    );

    // Anchor it (puts it in ANCHORED state)
    LocationData memory location = LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 });

    deployableSystem.anchor(smartObjectId, alice, location);
    vm.stopPrank();

    // Try to anchor it again (should fail since it's already ANCHORED)
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.ANCHORED)
    );
    deployableSystem.anchor(smartObjectId, alice, location);

    // Create a new deployable for successful anchoring test
    uint256 newSmartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 3, true);
    vm.startPrank(deployer);
    entitySystem.instantiate(deployableObjectClassId, newSmartObjectId, alice);
    _setupEntityRecord(newSmartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 3, 1000);
    vm.stopPrank();

    // Initialize new deployable (puts it in UNANCHORED state)
    vm.prank(alice, deployer);
    deployableSystem.createDeployable(
      newSmartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000

    // Get pre-anchor state for comparison
    assertEq(
      uint8(DeployableState.getCurrentState(newSmartObjectId)),
      uint8(State.UNANCHORED),
      "State should be UNANCHORED initially"
    );
    assertFalse(DeployableState.getIsValid(newSmartObjectId), "Deployable should not be valid initially");

    assertEq(ownershipSystem.owner(newSmartObjectId), alice, "Owner should be alice before anchoring");

    // Execute successful anchor (with ownership transfer)
    LocationData memory newLocation = LocationData({ solarSystemId: 2, x: 2000, y: 2001, z: 2002 });
    uint256 priorTimestamp = block.timestamp + 1000;
    vm.prank(bob, deployer);
    vm.warp(priorTimestamp);
    deployableSystem.anchor(newSmartObjectId, bob, newLocation);

    // Validate state changes after successful anchoring
    // State transition
    assertEq(
      uint8(DeployableState.getCurrentState(newSmartObjectId)),
      uint8(State.ANCHORED),
      "State should be ANCHORED"
    );
    assertEq(
      uint8(DeployableState.getPreviousState(newSmartObjectId)),
      uint8(State.UNANCHORED),
      "Previous state should be UNANCHORED"
    );

    // Validity flag
    assertTrue(DeployableState.getIsValid(newSmartObjectId), "Deployable should be valid after anchoring");

    // Timestamp updated
    assertEq(DeployableState.getAnchoredAt(newSmartObjectId), priorTimestamp, "Anchored timestamp should be set");

    // Ownership transfer
    assertEq(ownershipSystem.owner(newSmartObjectId), bob, "Owner should be changed to bob");

    // Location data set correctly
    LocationData memory savedLocation = Location.get(newSmartObjectId);
    assertEq(savedLocation.solarSystemId, newLocation.solarSystemId, "Solar system ID should match");
    assertEq(savedLocation.x, newLocation.x, "X coordinate should match");
    assertEq(savedLocation.y, newLocation.y, "Y coordinate should match");
    assertEq(savedLocation.z, newLocation.z, "Z coordinate should match");

    // Test case where ownership doesn't change (current owner is already correct)
    uint256 thirdSmartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 4, true);
    vm.startPrank(deployer);
    entitySystem.instantiate(deployableObjectClassId, thirdSmartObjectId, alice);
    _setupEntityRecord(thirdSmartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 4, 1000);
    vm.stopPrank();

    // Initialize new deployable with alice as owner
    vm.prank(alice, deployer);
    deployableSystem.createDeployable(
      thirdSmartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    ); // max amount is 1000000

    // Anchor it specifying alice again as owner (should not change ownership)
    vm.prank(alice, deployer);
    deployableSystem.anchor(thirdSmartObjectId, alice, newLocation);

    // Verify owner is still alice
    assertEq(ownershipSystem.owner(thirdSmartObjectId), alice, "Owner should still be alice");

    // Test case where there is no owner yet is already confirmed in the createAndAnchor test
  }

  function test_Unanchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Test revert case: Attempt to unanchor when state is not ANCHORED
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();
    vm.startPrank(alice, deployer);
    deployableSystem.createDeployable(smartObjectId, alice, 100, 60, 100000000); // max amount is 1000000
    vm.stopPrank();

    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    deployableSystem.unanchor(smartObjectId);

    // ANCHOR the deployable
    vm.prank(alice, deployer);
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 }));

    // Capture pre-unanchor state
    assertTrue(DeployableState.getIsValid(smartObjectId), "Deployable should be valid when anchored");
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.ANCHORED), "State should be ANCHORED");
    assertEq(ownershipSystem.owner(smartObjectId), alice, "Owner should be alice before unanchoring");

    // UNANCHOR the deployable
    vm.prank(alice, deployer);
    deployableSystem.unanchor(smartObjectId);

    // Validate all relevant state changes
    // State transition
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.UNANCHORED),
      "State should be UNANCHORED"
    );
    assertEq(
      uint8(DeployableState.getPreviousState(smartObjectId)),
      uint8(State.ANCHORED),
      "Previous state should be ANCHORED"
    );

    // Validity flag
    assertFalse(DeployableState.getIsValid(smartObjectId), "Deployable should not be valid after unanchoring");

    // Ownership removed
    assertEq(ownershipSystem.owner(smartObjectId), address(0), "Ownership should be removed");

    // Location data reset
    LocationData memory location = Location.get(smartObjectId);
    assertEq(location.solarSystemId, 0, "Solar system ID should be reset to 0");
    assertEq(location.x, 0, "X coordinate should be reset to 0");
    assertEq(location.y, 0, "Y coordinate should be reset to 0");
    assertEq(location.z, 0, "Z coordinate should be reset to 0");

    // Test unanchoring from ONLINE state
    uint256 onlineObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 6, true);
    vm.startPrank(deployer);
    entitySystem.instantiate(deployableObjectClassId, onlineObjectId, alice);
    _setupEntityRecord(onlineObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID + 6, 1000);
    vm.stopPrank();

    // Create, anchor, and bring online
    vm.startPrank(alice, deployer);
    deployableSystem.createDeployable(onlineObjectId, alice, 100, 60, 100000000); // max amount is 1000000
    deployableSystem.anchor(onlineObjectId, alice, LocationData({ solarSystemId: 2, x: 2000, y: 2001, z: 2002 }));

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI &&
        fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
    );

    // Add fuel and bring online
    fuelSystem.depositFuel(onlineObjectId, 1);
    deployableSystem.bringOnline(onlineObjectId);

    // Verify it's ONLINE
    assertEq(uint8(DeployableState.getCurrentState(onlineObjectId)), uint8(State.ONLINE), "State should be ONLINE");

    // Unanchor from ONLINE state
    deployableSystem.unanchor(onlineObjectId);
    vm.stopPrank();

    // Verify state transition
    assertEq(
      uint8(DeployableState.getCurrentState(onlineObjectId)),
      uint8(State.UNANCHORED),
      "State should be UNANCHORED"
    );
    assertEq(
      uint8(DeployableState.getPreviousState(onlineObjectId)),
      uint8(State.ONLINE),
      "Previous state should be ONLINE"
    );
    assertFalse(DeployableState.getIsValid(onlineObjectId), "Deployable should not be valid after unanchoring");
  }

  function test_BringOnline(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Test revert case: Attempt to bring online when state is not UNANCHORED
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();
    vm.startPrank(alice, deployer);
    deployableSystem.createDeployable(
      smartObjectId,
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );
    vm.stopPrank();

    // Test incorrect state (UNANCHORED) revert
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    deployableSystem.bringOnline(smartObjectId);

    // Now anchor the deployable to get to ANCHORED state
    vm.prank(alice, deployer);
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 }));

    // Test no fuel revert
    vm.prank(alice, deployer);
    vm.expectRevert(abi.encodeWithSelector(DeployableSystem.Deployable_NoFuel.selector, smartObjectId));
    deployableSystem.bringOnline(smartObjectId);

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId); // this will always be bigger than the calculated fuel amount
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI &&
        fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
    );

    // Add fuel and capture state before bringing online
    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.ANCHORED),
      "State should be ANCHORED before bringing online"
    );

    // Successfully bring online
    uint256 timestampBefore = block.timestamp;
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    // Verify relevant state changes
    // State transition
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.ONLINE), "State should be ONLINE");
    assertEq(
      uint8(DeployableState.getPreviousState(smartObjectId)),
      uint8(State.ANCHORED),
      "Previous state should be ANCHORED"
    );

    // Fuel consumption starts (verify last consumption timestamp is set)
    FuelData memory fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.lastUpdatedAt, timestampBefore, "Last consumption timestamp should be set");

    // Try to bring online when already online (should revert)
    vm.prank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.ONLINE)
    );
    deployableSystem.bringOnline(smartObjectId);

    // Test bringing online from ONLINE state after going offline
    // First, bring it offline
    vm.prank(alice, deployer);
    deployableSystem.bringOffline(smartObjectId);
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.ANCHORED),
      "State should be ANCHORED after bringing offline"
    );

    // Then, bring it online again
    vm.prank(alice, deployer);
    deployableSystem.bringOnline(smartObjectId);
    assertEq(
      uint8(DeployableState.getCurrentState(smartObjectId)),
      uint8(State.ONLINE),
      "State should be ONLINE after bringing online again"
    );
  }

  function test_BringOffline(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 2 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    // Setup: Create a deployable
    vm.startPrank(deployer);
    _setupEntityRecord(smartObjectId, SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, 1000);
    vm.stopPrank();
    vm.startPrank(alice, deployer);
    deployableSystem.createDeployable(smartObjectId, alice, 100, 60, 100000000); // max amount is 1000000
    vm.stopPrank();

    // Test revert case: Attempt to bring offline when state is UNANCHORED
    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.UNANCHORED)
    );
    deployableSystem.bringOffline(smartObjectId);

    // Anchor the deployable
    vm.prank(alice, deployer);
    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 1, x: 100, y: 200, z: 300 }));

    // Test revert case: Attempt to bring offline when state is ANCHORED
    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, smartObjectId, State.ANCHORED)
    );
    deployableSystem.bringOffline(smartObjectId);

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI &&
        fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
    );

    // Add fuel and bring the deployable online
    vm.prank(alice, deployer);
    fuelSystem.depositFuel(smartObjectId, 100);

    vm.prank(alice);
    deployableSystem.bringOnline(smartObjectId);

    // Verify current state is ONLINE
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.ONLINE));

    // Successfully bring the deployable offline
    vm.prank(alice);
    deployableSystem.bringOffline(smartObjectId);

    // Verify state has changed to ANCHORED
    assertEq(uint8(DeployableState.getCurrentState(smartObjectId)), uint8(State.ANCHORED));
    assertEq(uint8(DeployableState.getPreviousState(smartObjectId)), uint8(State.ONLINE));

    // Verify updated block information
    assertEq(DeployableState.getUpdatedBlockNumber(smartObjectId), block.number);
    assertEq(DeployableState.getUpdatedBlockTime(smartObjectId), block.timestamp);
  }

  function test_GlobalPause() public {
    vm.startPrank(deployer);
    deployableSystem.globalPause();
    vm.stopPrank();

    // validate state changes
    assertEq(GlobalDeployableState.getIsPaused(), true, "Deployables should be paused");
    assertEq(GlobalDeployableState.getUpdatedBlockNumber(), block.number, "Updated block number should be set");
    assertEq(GlobalDeployableState.getLastGlobalOffline(), block.timestamp, "Last global offline should be set");
  }

  function test_GlobalResume() public {
    vm.startPrank(deployer);
    deployableSystem.globalResume();
    vm.stopPrank();

    // validate state changes
    assertEq(GlobalDeployableState.getIsPaused(), false, "Deployables should be resumed");
    assertEq(GlobalDeployableState.getUpdatedBlockNumber(), block.number, "Updated block number should be set");
    assertEq(GlobalDeployableState.getLastGlobalOnline(), block.timestamp, "Last global online should be set");
  }

  function test_Inventory_interaction() public {
    // add inventory to the class scope
    TagParams memory inventoryTagParams = TagParams(
      TagIdLib.encode(TAG_TYPE_RESOURCE_RELATION, bytes30(ResourceId.unwrap(inventorySystem.toResourceId()))),
      abi.encode(
        ResourceRelationValue(
          "COMPOSITION",
          RESOURCE_SYSTEM,
          ResourceIdInstance.getResourceName(inventorySystem.toResourceId())
        )
      )
    );

    vm.prank(deployer);
    // tag the smart character class with the mock system
    tagSystem.setTag(deployableObjectClassId, inventoryTagParams);

    // check inventory version
    assertEq(Inventory.getVersion(smartObjectId), 0, "Inventory version should be 0");

    // create a deployable
    vm.prank(alice, deployer);
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        10,
        60,
        100000000,
        LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 })
      )
    );

    // check inventory was initialized
    assertEq(Inventory.getVersion(smartObjectId), 1, "Inventory version should be 1");

    // mock Inventory used capacity
    vm.prank(deployer);
    Inventory.setUsedCapacity(smartObjectId, 500);

    // unanchor the deployable
    vm.startPrank(alice, deployer);
    deployableSystem.unanchor(smartObjectId);

    // check inventory state
    assertEq(Inventory.getVersion(smartObjectId), 2, "Inventory version should be 2");
    assertEq(Inventory.getUsedCapacity(smartObjectId), 0, "Inventory used capacity should be 0");

    // anchor the deployable

    deployableSystem.anchor(smartObjectId, alice, LocationData({ solarSystemId: 1, x: 100, y: 200, z: 300 }));
    vm.stopPrank();

    // mock Inventory capacity again
    vm.prank(deployer);
    Inventory.setUsedCapacity(smartObjectId, 500);

    // destroy the deployable
    vm.prank(deployer);
    deployableSystem.destroyDeployable(smartObjectId);

    // check inventory state
    assertEq(Inventory.getVersion(smartObjectId), 3, "Inventory version should be 3");
    assertEq(Inventory.getUsedCapacity(smartObjectId), 0, "Inventory used capacity should be 0");
  }

  function test_SmartGate_integration() public {
    // create two deployable gates
    vm.startPrank(alice, deployer);
    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams(
        smartGate1Id,
        "SG",
        EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
          itemId: GATE_1_ID,
          volume: 1000
        }),
        alice,
        10,
        60,
        100000000,
        LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 })
      ),
      100
    );

    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams(
        smartGate2Id,
        "SG",
        EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
          itemId: GATE_2_ID,
          volume: 1000
        }),
        alice,
        10,
        60,
        100000000,
        LocationData({ solarSystemId: 1, x: 2, y: 2, z: 2 })
      ),
      100
    );

    // link the gates
    smartGateSystem.linkGates(smartGate1Id, smartGate2Id);

    // check if the gates are linked
    assertEq(smartGateSystem.isGateLinked(smartGate1Id, smartGate2Id), true, "Gates should be linked");

    // unanchor one of the gates
    deployableSystem.unanchor(smartGate1Id);

    // check if the gates are still linked
    assertEq(smartGateSystem.isGateLinked(smartGate1Id, smartGate2Id), false, "Gates should not be linked");

    // reanchor the gate
    deployableSystem.anchor(smartGate1Id, alice, LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 }));

    // re link the gates
    smartGateSystem.linkGates(smartGate1Id, smartGate2Id);

    // check if the gates are linked
    assertEq(smartGateSystem.isGateLinked(smartGate1Id, smartGate2Id), true, "Gates should be linked");
    vm.stopPrank();

    // destroy the destination gate
    vm.prank(deployer);
    deployableSystem.destroyDeployable(smartGate2Id);

    // check if the gates are linked
    assertEq(smartGateSystem.isGateLinked(smartGate1Id, smartGate2Id), false, "Gates should not be linked");
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
