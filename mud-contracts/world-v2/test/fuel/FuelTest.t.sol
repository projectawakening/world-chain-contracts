// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, CharactersByAccount, LocationData, EphemeralInventory, SmartAssembly, Fuel, Location, LocationData } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { State } from "../../src/codegen/common.sol";

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
import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

// Create a mock system to properly test system-to-system calls
contract MockFuelInteractSystem is System {
  function callConfigureFuelParameters(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    fuelSystem.configureFuelParameters(
      smartObjectId,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      fuelAmount
    );
  }

  function callSetFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    fuelSystem.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
  }

  function callSetFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public {
    fuelSystem.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds);
  }

  function callSetFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    fuelSystem.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
  }

  function callSetFuelAmount(uint256 smartObjectId, uint256 fuelAmountInWei) public {
    fuelSystem.setFuelAmount(smartObjectId, fuelAmountInWei);
  }

  function callDepositFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    fuelSystem.depositFuel(smartObjectId, fuelAmount);
  }

  function callWithdrawFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    fuelSystem.withdrawFuel(smartObjectId, fuelAmount);
  }

  function callUpdateFuel(uint256 smartObjectId) public {
    fuelSystem.updateFuel(smartObjectId);
  }
}

contract FuelTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  // Mock system address
  // MockFuelInteractSystem fuelMockSystem;
  // ResourceId fuelMockSystemId;

  IWorldWithContext public world;

  // Test variables
  uint256 deployableObjectClassId;
  uint256 smartObjectId;
  bytes32 tenantId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;

  // Test addresses
  address deployer;
  address alice;

  LocationData location;
  EntityRecordParams entityRecordParams;

  // Bounds for fuelUnitVolume
  uint256 constant MIN_FUEL_UNIT_VOLUME = 1;
  uint256 constant MAX_FUEL_UNIT_VOLUME = type(uint128).max - 1;

  // Bounds for timeElapsed
  uint256 constant MIN_TIME_ELAPSED = 3;
  uint256 constant MAX_TIME_ELAPSED = 100 * 365 days;

  // Bounds for fuelConsumptionIntervalInSeconds
  uint256 constant MIN_FUEL_CONSUMPTION_INTERVAL = 2;
  // MAX_FUEL_CONSUMPTION_INTERVAL will be calculated dynamically since it depends on timeElapsed
  // and should be less than timeElapsed and (type(uint256).max / 1e18)

  // Bounds for fuelAmount
  // Will be calculated dynamically as it depends on fuelConsumption
  uint256 constant MAX_FUEL_AMOUNT = type(uint128).max / ONE_UNIT_IN_WEI;

  // Bounds for fuelMaxCapacity
  // Lower bound depends on fuelAmount and fuelUnitVolume
  uint256 constant MAX_FUEL_MAX_CAPACITY = type(uint256).max - 1;

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

    vm.startPrank(deployer, deployer);

    // Mock smart character data for alice
    CharactersByAccount.set(alice, 1);

    // Setup tenant
    tenantId = Tenant.get();

    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_TYPE_ID, SMART_OBJECT_ID, true);

    // Register class and setup smart object state
    deployableObjectClassId = uint256(keccak256(abi.encodePacked(tenantId, SMART_OBJECT_TYPE_ID)));

    // // Create resource ID for the mock system using the proper format
    // bytes14 namespace = bytes14("evefrontier");
    // bytes16 name = bytes16("MockFuelInteract");
    // fuelMockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // // Deploy and register the mock system
    // fuelMockSystem = new MockFuelInteractSystem();

    // // Register the system with the world
    // world.registerSystem(fuelMockSystemId, fuelMockSystem, true);

    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = ownershipSystem.toResourceId();
    // systemIds[6] = fuelMockSystemId;

    entitySystem.registerClass(deployableObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(deployableObjectClassId, smartObjectId, alice);

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_OBJECT_TYPE_ID,
      itemId: SMART_OBJECT_ID,
      volume: 1000
    });

    location = LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 });

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function testConfigureFuelParameters(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds > 1 && fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18));
    vm.assume(fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    // Create and anchor deployable
    vm.startPrank(alice, deployer);
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );
    vm.stopPrank();

    assertEq(fuelUnitVolume, Fuel.getFuelUnitVolume(smartObjectId));
    assertEq(fuelConsumptionIntervalInSeconds, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
    assertEq(fuelMaxCapacity, Fuel.getFuelMaxCapacity(smartObjectId));
    assertEq(0, Fuel.getFuelAmount(smartObjectId));

    vm.startPrank(deployer);
    // Configure fuel parameters
    fuelSystem.configureFuelParameters(smartObjectId, 10, 20, 300, 30);
    vm.stopPrank();

    assertEq(10, Fuel.getFuelUnitVolume(smartObjectId));
    assertEq(20, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
    assertEq(300, Fuel.getFuelMaxCapacity(smartObjectId));
    assertEq((30) * ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
  }

  function testSetFuelUnitVolume(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );
    vm.stopPrank();

    assertEq(fuelUnitVolume, Fuel.getFuelUnitVolume(smartObjectId));

    vm.startPrank(deployer);
    // Set fuel unit volume
    fuelSystem.setFuelUnitVolume(smartObjectId, 10);
    vm.stopPrank();

    assertEq(10, Fuel.getFuelUnitVolume(smartObjectId));
  }

  function testSetFuelConsumptionIntervalInSeconds(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );
    vm.stopPrank();

    assertEq(fuelConsumptionIntervalInSeconds, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));

    vm.startPrank(deployer);
    // Set fuel consumption interval in seconds
    fuelSystem.setFuelConsumptionIntervalInSeconds(smartObjectId, 20);
    vm.stopPrank();

    assertEq(20, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
  }

  function testSetFuelMaxCapacity(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );
    vm.stopPrank();

    assertEq(fuelMaxCapacity, Fuel.getFuelMaxCapacity(smartObjectId));

    vm.startPrank(deployer);
    fuelSystem.setFuelMaxCapacity(smartObjectId, type(uint256).max);
    vm.stopPrank();

    assertEq(type(uint256).max, Fuel.getFuelMaxCapacity(smartObjectId));
  }

  function testDepositFuel(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );

    assertEq(0, Fuel.getFuelAmount(smartObjectId));

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI &&
        fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
    );

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    vm.stopPrank();

    assertEq(fuelAmount * ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  }

  function testDepositFuelTwice(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / (2 * ONE_UNIT_IN_WEI)); // deposit twice so deivide by 2
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );

    assertEq(0, Fuel.getFuelAmount(smartObjectId));

    // requirement specifically for depositFuel * 2
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / (2 * ONE_UNIT_IN_WEI) &&
        fuelAmount < ((fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI) / 2
    );

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    deployableSystem.bringOnline(smartObjectId);

    assertEq((fuelAmount * ONE_UNIT_IN_WEI) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    vm.stopPrank();

    assertEq((fuelAmount * ONE_UNIT_IN_WEI * 2) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  }

  function test_fuelConsumption(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(timeElapsed > 2 && timeElapsed < 100 * 365 days);
    vm.assume(
      fuelConsumptionIntervalInSeconds > 1 &&
        fuelConsumptionIntervalInSeconds < timeElapsed &&
        fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18)
    );
    uint256 fuelConsumption = (((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) +
      (1 * ONE_UNIT_IN_WEI)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(
      fuelAmount > fuelConsumption / ONE_UNIT_IN_WEI && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI
    );
    vm.assume(
      fuelMaxCapacity >= fuelAmount * fuelUnitVolume &&
        fuelMaxCapacity > fuelUnitVolume &&
        fuelMaxCapacity < type(uint256).max
    );

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity,
        location
      )
    );

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(
      fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI &&
        fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI
    );

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    assertEq((fuelAmount * ONE_UNIT_IN_WEI) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));

    vm.startPrank(deployer);
    vm.warp(block.timestamp + timeElapsed);
    fuelSystem.updateFuel(smartObjectId);
    vm.stopPrank();

    assertEq((fuelAmount * ONE_UNIT_IN_WEI) - fuelConsumption, Fuel.getFuelAmount(smartObjectId));
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  }

  // test fuel runs out
  function test_fuelConsumptionRunsOut(
    uint256 _fuelUnitVolume,
    uint256 _fuelConsumptionIntervalInSeconds,
    uint256 _fuelAmount,
    uint256 _timeElapsed
  ) public {
    // Use bound() for direct artificial range constraints to avoid fuzzer rejecting too many inputs
    uint256 fuelUnitVolume = bound(_fuelUnitVolume, 1, 1000);
    uint256 fuelConsumptionIntervalInSeconds = bound(_fuelConsumptionIntervalInSeconds, 60, 3600); // 1 minute to 1 hour
    uint256 timeElapsed = bound(_timeElapsed, 1 days, 10 days);

    // Calculate fuel consumption based on time and interval
    uint256 fuelConsumption = ((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) + ONE_UNIT_IN_WEI;

    // Ensure fuelAmount is less than what would be consumed (to ensure it runs out)
    uint256 fuelAmount = bound(_fuelAmount, 1, (fuelConsumption / ONE_UNIT_IN_WEI) - 1);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        entityRecordParams,
        alice,
        fuelUnitVolume,
        fuelConsumptionIntervalInSeconds,
        fuelAmount * fuelUnitVolume * 2,
        location
      )
    );

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
    assertEq((fuelAmount * ONE_UNIT_IN_WEI) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));

    vm.startPrank(deployer);
    vm.warp(block.timestamp + timeElapsed);
    fuelSystem.updateFuel(smartObjectId);
    vm.stopPrank();

    assertEq(0, Fuel.getFuelAmount(smartObjectId));
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function test_fuelRefundDuringGlobalOffline(
    uint256 _fuelAmount,
    uint256 _timeElapsedBeforeOffline,
    uint256 _globalOfflineDuration,
    uint256 _timeElapsedAfterOffline
  ) public {
    // Directly use the bounded values in calculations without storing in new variables
    // This reduces stack variable usage while ensuring proper input ranges

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(
      CreateAndAnchorParams(
        smartObjectId,
        "SSU",
        EntityRecordParams({ tenantId: tenantId, typeId: SMART_OBJECT_TYPE_ID, itemId: SMART_OBJECT_ID, volume: 1000 }),
        alice,
        100,
        3600000000000, // Fixed value to avoid issues
        bound(_fuelAmount, 100, 10000) * 100 * 2, // Direct calculation of capacity
        location
      )
    );

    fuelSystem.depositFuel(smartObjectId, bound(_fuelAmount, 100, 10000));
    deployableSystem.bringOnline(smartObjectId);

    // Record fuel after bring online
    uint256 startingFuelAmount = Fuel.getFuelAmount(smartObjectId);
    uint256 startTime = block.timestamp;
    vm.stopPrank();

    // Perform the global offline/online sequence
    vm.startPrank(deployer);
    vm.warp(block.timestamp + bound(_timeElapsedBeforeOffline, 1 hours, 7 days));
    uint256 globalPauseTime = block.timestamp;
    deployableSystem.globalPause();
    vm.warp(block.timestamp + bound(_globalOfflineDuration, 1 hours, 24 hours));
    uint256 globalResumeTime = block.timestamp;
    deployableSystem.globalResume();
    vm.warp(block.timestamp + bound(_timeElapsedAfterOffline, 1 hours, 7 days));

    // Calculate expected fuel amount using helper function
    uint256 expectedFuelRemaining = _calculateExpectedFuel(
      startingFuelAmount,
      startTime,
      globalPauseTime,
      globalResumeTime,
      block.timestamp,
      3600000000000
    );

    // Update the fuel in the contract
    fuelSystem.updateFuel(smartObjectId);

    // Round values to nearest whole number before comparison
    uint256 actualFuelRemaining = (Fuel.getFuelAmount(smartObjectId) / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;
    expectedFuelRemaining = (expectedFuelRemaining / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;

    assertEq(actualFuelRemaining, expectedFuelRemaining);
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
    vm.stopPrank();
  }

  // Helper function to calculate expected fuel (reduces stack variables in main function)
  function _calculateExpectedFuel(
    uint256 startingFuelAmount,
    uint256 startTime,
    uint256 globalPauseTime,
    uint256 globalResumeTime,
    uint256 currentTime,
    uint256 fuelConsumptionIntervalInSeconds
  ) internal pure returns (uint256) {
    // Calculate regular consumption for the total time elapsed
    uint256 totalTimeElapsedSeconds = currentTime - startTime;
    uint256 fuelConsumed = (totalTimeElapsedSeconds * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds;

    // Calculate the global offline refund
    uint256 elapsedRefundTime = 0;
    if (startTime <= globalPauseTime) {
      elapsedRefundTime = globalResumeTime - globalPauseTime;
    }
    uint256 globalRefund = (elapsedRefundTime * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds;

    // Subtract refund from consumed fuel
    if (globalRefund <= fuelConsumed) {
      fuelConsumed -= globalRefund;
    } else {
      fuelConsumed = 0;
    }

    // Calculate remaining fuel
    if (fuelConsumed >= startingFuelAmount) {
      return 0;
    } else {
      return startingFuelAmount - fuelConsumed;
    }
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
