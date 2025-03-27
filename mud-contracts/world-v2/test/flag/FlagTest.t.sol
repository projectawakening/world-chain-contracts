// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

// MUD imports
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { GlobalDeployableState, Tenant, EntityRecord, EntityRecordData, DeployableState, DeployableStateData, SmartAssembly, Fuel, FuelData, Location, LocationData, CharactersByAccount } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FlagSystem, flagSystem } from "../../src/namespaces/evefrontier/codegen/systems/FlagSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { anchorSystem } from "../../src/namespaces/evefrontier/codegen/systems/AnchorSystemLib.sol";
import { smartGateSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

import { ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

contract FlagTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Item variables
  bytes32 tenantId;

  // Test addresses
  address deployer;
  address alice;

  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 smartObjectId;

  // Location data
  LocationData locationParams;

  // Entity record
  EntityRecordParams entityRecordParams;

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

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = keccak256(abi.encodePacked("TEST"));

    // Setup smart object IDs
    smartObjectId = _calculateObjectId(
      EntityRecord.getTypeId(flagSystem.getFlagClassId()),
      SMART_OBJECT_ID,
      true
    );

    locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: EntityRecord.getTypeId(flagSystem.getFlagClassId()),
      itemId: SMART_OBJECT_ID,
      volume: 1 // Flags have volume of 1 as per .env
    });

    vm.stopPrank();

    // allow global resume for deployable activity
    vm.prank(deployer);
    deployableSystem.globalResume();
    vm.resumeGasMetering();
  }

  function test_createFlag() public {
    vm.pauseGasMetering();
    
    // Check initial state
    assertEq(EntityRecord.getExists(smartObjectId), false);
    assertEq(keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))), keccak256(abi.encodePacked("")));
    
    DeployableStateData memory deployableStateData = DeployableState.get(smartObjectId);
    assertEq(deployableStateData.createdAt, 0);
    assertEq(uint8(deployableStateData.previousState), uint8(State.NULL));
    assertEq(uint8(deployableStateData.currentState), uint8(State.NULL));
    assertEq(deployableStateData.isValid, false);
    assertEq(deployableStateData.anchoredAt, 0);

    // Create flag
    vm.startPrank(deployer, deployer);
    flagSystem.createFlag(
      CreateAndAnchorParams(
        smartObjectId,
        "FLAG",
        entityRecordParams,
        alice,
        1, // Fuel unit volume
        3600, // Fuel consumption interval (1 hour)
        100, // Fuel max capacity
        locationParams,
        0 // no need for anchor because we are an anchor
      )
    );
    vm.stopPrank();

    // Verify final state
    assertEq(EntityRecord.getExists(smartObjectId), true);
    
    EntityRecordData memory entityRecordData = EntityRecord.get(smartObjectId);
    assertEq(entityRecordData.tenantId, tenantId);
    assertEq(entityRecordData.typeId, EntityRecord.getTypeId(flagSystem.getFlagClassId()));
    assertEq(entityRecordData.itemId, SMART_OBJECT_ID);
    assertEq(entityRecordData.volume, 1);

    assertEq(
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))),
      keccak256(abi.encodePacked("FLAG"))
    );

    deployableStateData = DeployableState.get(smartObjectId);
    assertEq(deployableStateData.createdAt, block.timestamp);
    assertEq(uint8(deployableStateData.previousState), uint8(State.UNANCHORED));
    assertEq(uint8(deployableStateData.currentState), uint8(State.ANCHORED));
    assertEq(deployableStateData.isValid, true);
    assertEq(deployableStateData.anchoredAt, block.timestamp);

    // Verify ownership
    address owner = ownershipSystem.owner(smartObjectId);
    assertEq(owner, alice);

    // Verify location
    LocationData memory locationData = Location.get(smartObjectId);
    assertEq(locationData.solarSystemId, locationParams.solarSystemId);
    assertEq(locationData.x, locationParams.x);
    assertEq(locationData.y, locationParams.y);
    assertEq(locationData.z, locationParams.z);

    // Verify fuel parameters
    FuelData memory fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.fuelUnitVolume, 1);
    assertEq(fuelData.fuelConsumptionIntervalInSeconds, 3600);
    assertEq(fuelData.fuelMaxCapacity, 100);
    assertEq(fuelData.fuelAmount, 0); // Initial fuel amount should be 0
    assertEq(fuelData.lastUpdatedAt, block.timestamp);

    vm.resumeGasMetering();
  }

  function test_anchorFuelConsumption() public {
    vm.pauseGasMetering();
    
    // Create flag
    vm.startPrank(deployer, deployer);
    flagSystem.createFlag(
      CreateAndAnchorParams(
        smartObjectId,
        "FLAG",
        entityRecordParams,
        alice,
        1, // Fuel unit volume
        3600, // Fuel consumption interval (1 hour)
        100, // Fuel max capacity
        locationParams,
        0 // no need for anchor because we are an anchor
      )
    );

    // Create two smart gates to anchor
    uint256 gate1Id = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      SMART_OBJECT_ID + 1,
      true
    );
    
    uint256 gate2Id = _calculateObjectId(
      EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
      SMART_OBJECT_ID + 2,
      true
    );

    // Create gate 1 with 1 hour fuel consumption
    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams(
        gate1Id,
        "GATE1",
        EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
          itemId: SMART_OBJECT_ID + 1,
          volume: 1
        }),
        alice,
        1, // Fuel unit volume
        1 hours,
        100, // Fuel max capacity
        locationParams,
        smartObjectId
      ),
      1000 // maxDistance in meters
    );

    // Create gate 2 with 30 minute fuel consumption
    smartGateSystem.createAndAnchorGate(
      CreateAndAnchorParams(
        gate2Id,
        "GATE2",
        EntityRecordParams({
          tenantId: tenantId,
          typeId: EntityRecord.getTypeId(smartGateSystem.getSmartGateClassId()),
          itemId: SMART_OBJECT_ID + 2,
          volume: 1
        }),
        alice,
        1, 
        30 minutes,
        100,
        locationParams,
        smartObjectId
      ),
      1000
    );

    // Set initial fuel amount on the flag (anchor)
    fuelSystem.setFuelAmount(smartObjectId, 100 * ONE_UNIT_IN_WEI);

    deployableSystem.bringOnline(smartObjectId);

    // Fast forward 1 hour
    vm.warp(block.timestamp + 3600);

    // Check fuel consumption
    // The flag (anchor) stores the fuel
    // The consumption rate is determined by the anchored objects:
    // - Gate 1: 1 unit per hour
    // - Gate 2: 2 units per hour (1 unit per 30 minutes)
    // Total consumption rate: 3 units per hour
    // After 1 hour, should have consumed 3 units
    // Bringing a deployable online spends 1 fuel
    // Total of 4 consumed
    assertEq(fuelSystem.currentFuelAmountInWei(smartObjectId), 96 * ONE_UNIT_IN_WEI); // Should have consumed 3 units

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
} 