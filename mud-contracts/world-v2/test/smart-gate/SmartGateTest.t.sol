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
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { Role, HasRole } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, InventoryItemData, InventoryItem, CharactersByAccount, OwnershipByObject, LocationData, SmartAssembly, SmartGateConfig, SmartGateConfigData, SmartGateLink, SmartGateLinkData, Fuel, FuelData, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { EphemeralInteractSystem, ephemeralInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { InventoryInteractSystem, inventoryInteractSystem } from "../../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { SmartGateSystem, smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

// Create a mock custom system to call when canJump is called
// This fits the expected builder pattern -
//   - create a custom contract that handles the canJump logic, and
//   - then configure the smart gate to use this custom system
contract MockCanJumpCustomSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return false;
  }
}

contract SmartGateTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // custom canJump system variables
  ResourceId customSystemId;
  MockCanJumpCustomSystem customSystem;

  // Item variables
  bytes32 tenantId;

  // Test addresses
  address deployer;
  address alice;
  address bob;
  address charlie;

  uint256 constant SOURCE_GATE_ID = 1234;
  uint256 constant DESTINATION_GATE_ID = 1235;
  uint256 constant INVALID_SOURCE_GATE_ID = 1236;
  uint256 constant INVALID_DESTINATION_GATE_ID = 1237;

  uint256 sourceGateId;
  uint256 destinationGateId;

  uint256 invalidSourceGateId;
  uint256 invalidDestinationGateId;

  // Location data
  LocationData sourceLocationParams;
  LocationData destinationLocationParams;

  //entity record
  EntityRecordParams sourceEntityRecordParams;
  EntityRecordParams destinationEntityRecordParams;

  uint256 fuelUnitVolume = 10;
  uint256 fuelConsumptionIntervalInSeconds = 60;
  uint256 fuelMaxCapacity = 1000000;

  uint256 maxDistance = 1; // will increase after testing failure

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
    sourceGateId = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      SOURCE_GATE_ID,
      true
    );
    destinationGateId = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      DESTINATION_GATE_ID,
      true
    );

    invalidSourceGateId = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      INVALID_SOURCE_GATE_ID,
      true
    );
    entitySystem.instantiate(smartGateSystem.getSmartGateClassId(), invalidSourceGateId, alice);
    invalidDestinationGateId = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      INVALID_DESTINATION_GATE_ID,
      true
    );
    entitySystem.instantiate(smartGateSystem.getSmartGateClassId(), invalidDestinationGateId, alice);

    sourceLocationParams = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    destinationLocationParams = LocationData({ solarSystemId: 2, x: 2, y: 2, z: 2 });

    sourceEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      itemId: SOURCE_GATE_ID,
      volume: 10000
    });

    destinationEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      itemId: DESTINATION_GATE_ID,
      volume: 10000
    });

    // vm.startPrank(bob, deployer);
    // fuelSystem.depositFuel(inventoryObjectId2, 10000);
    // deployableSystem.bringOnline(inventoryObjectId2);
    // vm.stopPrank();

    // Mock builder deployment of custom canJumpsystem
    bytes14 namespace = bytes14("spaceforalice");
    bytes16 name = bytes16("MockCanJumpCusto");
    // Create resource ID for the mock system using the proper format
    customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    vm.startPrank(alice);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Deploy and register the mock system
    customSystem = new MockCanJumpCustomSystem();

    // Register the system with the world
    world.registerSystem(customSystemId, customSystem, true);

    vm.stopPrank();

    // allow global resume for deployable activity
    vm.prank(deployer);
    deployableSystem.globalResume();
    vm.resumeGasMetering();
  }

  function test_createAndAnchorSmartGate() public {
    // all create and anchor internal reverts are tested in DeployableTest, SmartAssemblyTest and EntityRecordTest
    vm.pauseGasMetering();
    // check entity record data before creating and anchoring
    assertEq(EntityRecord.getExists(sourceGateId), false);

    // smart assembly data before creating and anchoring
    assertEq(keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(sourceGateId))), keccak256(abi.encodePacked("")));

    // check deployable data before creating and anchoring
    DeployableStateData memory deployableStateData = DeployableState.get(sourceGateId);

    assertEq(deployableStateData.createdAt, 0);
    assertEq(uint8(deployableStateData.previousState), uint8(State.NULL));
    assertEq(uint8(deployableStateData.currentState), uint8(State.NULL));
    assertEq(deployableStateData.isValid, false);
    assertEq(deployableStateData.anchoredAt, 0);
    assertEq(deployableStateData.updatedBlockNumber, 0);
    assertEq(deployableStateData.updatedBlockTime, 0);

    // check fuel data before creating and anchoring
    FuelData memory fuelData = Fuel.get(sourceGateId);
    assertEq(fuelData.fuelUnitVolume, 0);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, 0);
    assertEq(fuelData.fuelMaxCapacity, 0);

    // check ownership data before creating and anchoring
    address owner = ownershipSystem.owner(sourceGateId);
    assertEq(owner, address(0));

    // check location data before creating and anchoring
    LocationData memory locationData = Location.get(sourceGateId);
    assertEq(locationData.solarSystemId, 0);
    assertEq(locationData.x, 0);
    assertEq(locationData.y, 0);
    assertEq(locationData.z, 0);

    vm.startPrank(alice, deployer);
    // create and anchor source gate
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(
        SmartGateSystem.createAndAnchorGate,
        (
          CreateAndAnchorParams(
            sourceGateId,
            "SG",
            sourceEntityRecordParams,
            alice,
            fuelUnitVolume,
            fuelConsumptionIntervalInSeconds,
            fuelMaxCapacity,
            sourceLocationParams
          ),
          maxDistance
        )
      )
    );
    vm.stopPrank();

    // check entity record data after creating and anchoring
    assertEq(EntityRecord.getExists(sourceGateId), true);

    EntityRecordData memory entityRecordData = EntityRecord.get(sourceGateId);
    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()));
    assertEq(entityRecordData.itemId, SOURCE_GATE_ID);
    assertEq(entityRecordData.volume, 10000);

    // smart assembly data after creating and anchoring
    assertEq(
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(sourceGateId))),
      keccak256(abi.encodePacked("SG"))
    );

    // check deployable data after creating and anchoring
    deployableStateData = DeployableState.get(sourceGateId);

    assertEq(deployableStateData.createdAt, block.timestamp);
    assertEq(uint8(deployableStateData.previousState), uint8(State.UNANCHORED));
    assertEq(uint8(deployableStateData.currentState), uint8(State.ANCHORED));
    assertEq(deployableStateData.isValid, true);
    assertEq(deployableStateData.anchoredAt, block.timestamp);
    assertEq(deployableStateData.updatedBlockNumber, block.number);
    assertEq(deployableStateData.updatedBlockTime, block.timestamp);

    // check fuel data after creating and anchoring
    fuelData = Fuel.get(sourceGateId);
    assertEq(fuelData.fuelUnitVolume, fuelUnitVolume);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, fuelConsumptionIntervalInSeconds);
    assertEq(fuelData.fuelMaxCapacity, fuelMaxCapacity);

    // check ownership data after creating and anchoring
    owner = ownershipSystem.owner(sourceGateId);
    assertEq(owner, alice);

    // check location data after creating and anchoring
    locationData = Location.get(sourceGateId);
    assertEq(locationData.solarSystemId, sourceLocationParams.solarSystemId);
    assertEq(locationData.x, sourceLocationParams.x);
    assertEq(locationData.y, sourceLocationParams.y);
    assertEq(locationData.z, sourceLocationParams.z);
    vm.resumeGasMetering();
  }

  function test_linkGates() public {
    // turn off access control for testing
    vm.startPrank(deployer);
    accessConfigSystem.setAccessEnforcement(smartGateSystem.toResourceId(), SmartGateSystem.linkGates.selector, false);
    vm.stopPrank();

    // expect revert if source gate is not created
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, invalidSourceGateId, State.NULL)
    );
    vm.startPrank(alice, deployer);
    smartGateSystem.linkGates(invalidSourceGateId, destinationGateId);

    // create and anchor source gate
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(
        SmartGateSystem.createAndAnchorGate,
        (
          CreateAndAnchorParams(
            sourceGateId,
            "SG",
            sourceEntityRecordParams,
            alice,
            fuelUnitVolume,
            fuelConsumptionIntervalInSeconds,
            fuelMaxCapacity,
            sourceLocationParams
          ),
          maxDistance
        )
      )
    );

    // expect revert if destination gate is not created
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, invalidDestinationGateId, State.NULL)
    );
    smartGateSystem.linkGates(sourceGateId, invalidDestinationGateId);

    // create and anchor destination gate
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(
        SmartGateSystem.createAndAnchorGate,
        (
          CreateAndAnchorParams(
            destinationGateId,
            "SG",
            destinationEntityRecordParams,
            bob,
            fuelUnitVolume,
            fuelConsumptionIntervalInSeconds,
            fuelMaxCapacity,
            destinationLocationParams
          ),
          maxDistance
        )
      )
    );

    // turn access control on
    vm.startPrank(deployer);
    accessConfigSystem.setAccessEnforcement(smartGateSystem.toResourceId(), SmartGateSystem.linkGates.selector, true);
    vm.stopPrank();

    // revert access if gates are not both owned by the same caller
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(AccessSystem.Access_NotAdminSupportedOrDirectOwnerGates.selector, alice, sourceGateId)
    );
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    // mock alice as owner of the destination gate
    vm.startPrank(deployer);
    OwnershipByObject.set(destinationGateId, alice);
    vm.stopPrank();

    // expect revert when source and destination are the same
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_SameSourceAndDestination.selector, sourceGateId, sourceGateId)
    );
    vm.prank(alice, deployer);
    smartGateSystem.linkGates(sourceGateId, sourceGateId);

    // expect revert when gates are not within range
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_NotWithtinRange.selector, sourceGateId, destinationGateId)
    );
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    // increase maxRange
    vm.startPrank(deployer);
    SmartGateConfig.setMaxDistance(sourceGateId, 10);
    vm.stopPrank();

    // mock DESTROYED state for sourcegate
    vm.startPrank(deployer);
    DeployableState.setCurrentState(sourceGateId, State.DESTROYED);
    vm.stopPrank();

    // expect revert when source gate is destroyed
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, sourceGateId, State.DESTROYED)
    );
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    // reset source gate state and set the destination state to destroyed
    vm.startPrank(deployer);
    DeployableState.setCurrentState(sourceGateId, State.ANCHORED);
    DeployableState.setCurrentState(destinationGateId, State.DESTROYED);
    vm.stopPrank();

    // expect revert when destination gate is destroyed
    vm.startPrank(alice, deployer);
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, destinationGateId, State.DESTROYED)
    );
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    //reset destination gate state
    vm.startPrank(deployer);
    DeployableState.setCurrentState(destinationGateId, State.ANCHORED);
    vm.stopPrank();

    // successfully link gates
    vm.startPrank(alice, deployer);
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    // revert if either gate is already linked
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateAlreadyLinked.selector, sourceGateId, destinationGateId)
    );
    vm.startPrank(alice, deployer);
    smartGateSystem.linkGates(sourceGateId, destinationGateId);
    vm.stopPrank();
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

  function test_unlinkGates() public {
    test_linkGates();

    assertEq(OwnershipByObject.get(sourceGateId), alice);
    assertEq(OwnershipByObject.get(destinationGateId), alice);

    vm.startPrank(alice, deployer);
    smartGateSystem.unlinkGates(sourceGateId, destinationGateId);
    vm.stopPrank();

    bool isLinked = smartGateSystem.isGateLinked(sourceGateId, destinationGateId);
    assert(!isLinked);

    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotLinked.selector, sourceGateId, destinationGateId)
    );
    vm.startPrank(alice, deployer);
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.unlinkGates, (sourceGateId, destinationGateId))
    );
    vm.stopPrank();
  }

  function test_canJump() public {
    uint256 characterId = 1;
    test_linkGates();

    // NOTE: canJump checks fail when using the MUD system libs for a view function call
    // Test revert when gates are not online
    // Try to jump, expecting a revert
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GatesNotOnline.selector, sourceGateId, destinationGateId)
    );
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.canJump, (characterId, sourceGateId, destinationGateId))
    );

    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(sourceGateId, 1000);
    deployableSystem.bringOnline(sourceGateId);
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotOnline.selector, destinationGateId));
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.canJump, (characterId, sourceGateId, destinationGateId))
    );

    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(destinationGateId, 1000);
    deployableSystem.bringOnline(destinationGateId);
    vm.stopPrank();

    vm.prank(deployer);
    DeployableState.setCurrentState(sourceGateId, State.ANCHORED);

    vm.expectRevert(abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotOnline.selector, sourceGateId));
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.canJump, (characterId, sourceGateId, destinationGateId))
    );

    vm.startPrank(deployer);
    DeployableState.setCurrentState(sourceGateId, State.ONLINE);
    // mock invalid destination gate state
    DeployableState.setCurrentState(invalidDestinationGateId, State.ONLINE);
    vm.stopPrank();

    // Try to jump between unlinked gates, expecting a revert
    vm.expectRevert(
      abi.encodeWithSelector(SmartGateSystem.SmartGate_GateNotLinked.selector, sourceGateId, invalidDestinationGateId)
    );
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.canJump, (characterId, sourceGateId, invalidDestinationGateId))
    );

    // successfully jump
    bool canJump = smartGateSystem.canJump(characterId, sourceGateId, destinationGateId);
    assert(canJump);

    bool canJumpReverse = smartGateSystem.canJump(characterId, destinationGateId, sourceGateId);
    assert(canJumpReverse);
  }

  function test_configureGate() public {
    uint256 characterId = 1;
    test_linkGates();

    vm.prank(deployer);
    // mock invalid source gate ownership
    OwnershipByObject.set(invalidSourceGateId, alice);

    // test revert configure in wrong state
    vm.expectRevert(
      abi.encodeWithSelector(DeployableSystem.Deployable_IncorrectState.selector, invalidSourceGateId, State.NULL)
    );
    vm.startPrank(alice);
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.configureGate, (invalidSourceGateId, customSystemId))
    );
    vm.stopPrank();

    // success
    vm.startPrank(alice);
    smartGateSystem.configureGate(sourceGateId, customSystemId);
    vm.stopPrank();

    vm.startPrank(alice, deployer);
    fuelSystem.depositFuel(sourceGateId, 1000);
    deployableSystem.bringOnline(sourceGateId);

    fuelSystem.depositFuel(destinationGateId, 1000);
    deployableSystem.bringOnline(destinationGateId);
    vm.stopPrank();

    ResourceId systemId = SmartGateConfig.getSystemId(sourceGateId);
    assertEq(ResourceId.unwrap(systemId), ResourceId.unwrap(customSystemId));
    bool canJump = smartGateSystem.canJump(characterId, sourceGateId, destinationGateId);
    assert(!canJump);
  }

  // TODO: move to access control tests
  function test_DeployerCannotLinkSmartGates() public {
    test_createAndAnchorSmartGate();

    vm.expectRevert(
      abi.encodeWithSelector(AccessSystem.Access_NotAdminSupportedOrDirectOwnerGates.selector, deployer, sourceGateId)
    );
    vm.startPrank(deployer);
    world.call(
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.linkGates, (sourceGateId, destinationGateId))
    );
    vm.stopPrank();
  }
}
