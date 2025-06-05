// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, DeployableState, CharactersByAccount, LocationData, EphemeralInventory, SmartAssembly, Fuel, FuelData, FuelConsumptionState, FuelEfficiencyConfig, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

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
import { FuelParams } from "../../src/namespaces/evefrontier/systems/fuel/types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

import { ObjectIdLib } from "../../src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

// Create a mock system to properly test system-to-system calls
contract MockFuelInteractSystem is System {
  function callConfigureFuelParameters(uint256 smartObjectId, FuelParams memory fuelParams) public {
    fuelSystem.configureFuelParameters(smartObjectId, fuelParams);
  }

  function callConfigureFuelEfficiency(
    uint256 smartObjectId,
    EntityRecordParams memory fuelEntityRecordParams,
    uint256 fuelEfficiency
  ) public {
    fuelSystem.configureFuelEfficiency(smartObjectId, fuelEntityRecordParams, fuelEfficiency);
  }

  function callStartBurn(uint256 smartObjectId) public {
    fuelSystem.startBurn(smartObjectId);
  }

  function callStopBurn(uint256 smartObjectId) public {
    fuelSystem.stopBurn(smartObjectId);
  }

  function callUpdateFuel(uint256 smartObjectId) public {
    fuelSystem.updateFuel(smartObjectId);
  }
}

contract FuelTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  // Mock system address
  MockFuelInteractSystem fuelMockSystem;
  ResourceId fuelMockSystemId;

  IWorldWithContext public world;

  // Test variables
  uint256 deployableObjectClassId;
  uint256 smartObjectId;
  bytes32 tenantId;
  uint256 fuelSmartObjectId;
  uint256 fuelSmartObjectId2;
  uint256 invalidFuelSmartObjectId;

  // Smart Object variables
  uint256 constant SMART_OBJECT_ID = 1234;
  uint256 constant SMART_OBJECT_TYPE_ID = 1235;

  // Test addresses
  address deployer;
  address alice;

  LocationData location;
  EntityRecordParams entityRecordParams;
  EntityRecordParams fuelEntityRecordParams;
  EntityRecordParams fuelEntityRecordParams2;

  // Bounds for fuelUnitVolume
  uint256 constant MIN_FUEL_UNIT_VOLUME = 1;
  uint256 constant MAX_FUEL_UNIT_VOLUME = type(uint128).max - 1;

  // Bounds for fuelBurnRateInSeconds
  uint256 constant MIN_FUEL_BURN_RATE = 60;
  uint256 constant MAX_FUEL_BURN_RATE = type(uint128).max;

  // Bounds for fuelAmount
  uint256 constant MAX_FUEL_AMOUNT = type(uint128).max / ONE_UNIT_IN_WEI;

  // Bounds for fuelMaxCapacity
  uint256 constant MAX_FUEL_MAX_CAPACITY = type(uint128).max;

  uint256 constant TEST_FUEL_TYPE_ID = 1;
  uint256 constant TEST_FUEL_TYPE_ID_2 = 2;
  uint256 constant INVALID_FUEL_TYPE_ID = 2;

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

    fuelSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, TEST_FUEL_TYPE_ID);
    fuelSmartObjectId2 = ObjectIdLib.calculateObjectId(tenantId, TEST_FUEL_TYPE_ID_2);

    invalidFuelSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, INVALID_FUEL_TYPE_ID);

    // Create resource ID for the mock system
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockFuelInteract");
    fuelMockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    // Deploy and register the mock system
    fuelMockSystem = new MockFuelInteractSystem();
    world.registerSystem(fuelMockSystemId, fuelMockSystem, true);

    // Register class and setup smart object state
    deployableObjectClassId = uint256(keccak256(abi.encodePacked(tenantId, SMART_OBJECT_TYPE_ID)));

    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = deployableSystem.toResourceId();
    systemIds[1] = smartAssemblySystem.toResourceId();
    systemIds[2] = entityRecordSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = fuelSystem.toResourceId();
    systemIds[5] = ownershipSystem.toResourceId();
    systemIds[6] = fuelMockSystemId;
    entitySystem.registerClass(deployableObjectClassId, systemIds);

    // instantiate the smart object
    entitySystem.instantiate(deployableObjectClassId, smartObjectId, alice);

    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: SMART_OBJECT_TYPE_ID,
      itemId: SMART_OBJECT_ID,
      volume: 1000
    });

    fuelEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: TEST_FUEL_TYPE_ID,
      itemId: 0,
      volume: 28 * (10 ** 16)
    });

    fuelEntityRecordParams2 = EntityRecordParams({
      tenantId: tenantId,
      typeId: TEST_FUEL_TYPE_ID_2,
      itemId: 0,
      volume: 100
    });

    location = LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 });

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_configureFuelParameters() public {
    vm.startPrank(deployer);

    // Configure fuel efficiency first
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);

    // Test valid configuration
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );

    // Verify configuration
    assertEq(Fuel.getFuelMaxCapacity(smartObjectId), 10000);
    assertEq(Fuel.getFuelBurnRateInSeconds(smartObjectId), 3600);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0);

    // Test invalid configurations
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelMaxCapacity.selector,
        smartObjectId,
        0,
        1,
        uint256(type(uint128).max)
      )
    );
    fuelSystem.configureFuelParameters(smartObjectId, FuelParams({ fuelMaxCapacity: 0, fuelBurnRateInSeconds: 3600 }));

    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelBurnRate.selector,
        smartObjectId,
        30,
        60,
        uint256(type(uint128).max)
      )
    );
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 30 })
    );

    vm.stopPrank();
  }

  function test_configureFuelEfficiency() public {
    vm.startPrank(deployer);

    // Test valid configuration
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 80);
    assertEq(FuelEfficiencyConfig.getEfficiency(fuelSmartObjectId), 80);

    // Test invalid configurations
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelTypeId.selector, 1, fuelEntityRecordParams.typeId)
    );
    fuelSystem.configureFuelEfficiency(1, fuelEntityRecordParams, 80); // Invalid fuel type

    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelEfficiency.selector, fuelSmartObjectId, 101, 10, 100)
    );
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 101); // Efficiency > 100

    vm.stopPrank();
  }

  function test_depositAndWithdrawFuel() public {
    vm.startPrank(deployer);

    // Setup initial configuration
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(smartObjectId, FuelParams({ fuelMaxCapacity: 10, fuelBurnRateInSeconds: 3600 }));

    // Test deposit
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    assertEq(Fuel.getFuelAmount(smartObjectId), 5);

    // Test withdraw
    fuelSystem.withdrawFuel(smartObjectId, 2);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);

    // Test invalid operations
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelSmartObjectId.selector, smartObjectId, invalidFuelSmartObjectId)
    );
    fuelSystem.depositFuel(smartObjectId, invalidFuelSmartObjectId, 8); // Invalid fuel type id

    vm.expectRevert(abi.encodeWithSelector(FuelSystem.Fuel_ExceedsMaxCapacity.selector, smartObjectId, 38, 11, 10));
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 38); // Would exceed max capacity , can accept 35

    vm.expectRevert(abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelAmount.selector, smartObjectId, 4, 1, 3));
    fuelSystem.withdrawFuel(smartObjectId, 4); // Not enough fuel

    vm.expectRevert(abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelAmount.selector, smartObjectId, 0, 1, 3));
    fuelSystem.withdrawFuel(smartObjectId, 0); // Cannot withdraw 0

    //deposit for Fuel_TypeMismatch
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId2, fuelEntityRecordParams2, 100);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_TypeMismatch.selector,
        smartObjectId,
        fuelSmartObjectId,
        fuelSmartObjectId2
      )
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId2, 1); // Type mismatch

    vm.stopPrank();
  }

  function test_burnFunctionality() public {
    vm.startPrank(deployer);

    // Setup initial configuration
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );

    // Start burn
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId);

    // Verify burn started
    (uint256 timeLeft, uint256 unitsToConsume, uint256 actualRate, uint256 fuelAmount) = fuelSystem
      .getCurrentFuelConsumptionStatus(smartObjectId);
    assertTrue(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(fuelAmount, 4); // One unit consumed on start
    assertEq(actualRate, 3600); // 100% efficiency
    assertEq(unitsToConsume, 0);
    assertTrue(timeLeft <= 3600);

    // Advance time by 2 hours
    vm.warp(block.timestamp + 7200);

    // Update fuel state
    fuelSystem.updateFuel(smartObjectId);

    // Check state after burn
    assertTrue(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(Fuel.getFuelAmount(smartObjectId), 2); // Should have consumed 2 more units

    //deposit fuel of the same type should work
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 1);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);

    //deposit fuel of different type
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId2, fuelEntityRecordParams2, 100);
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_TypeMismatch.selector,
        smartObjectId,
        fuelSmartObjectId,
        fuelSmartObjectId2
      )
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId2, 1);

    // Stop burn
    fuelSystem.stopBurn(smartObjectId);

    // Verify burn stopped
    assertFalse(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    //deposit of the same fuel type should work after stop burn
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 1);
    assertEq(Fuel.getFuelAmount(smartObjectId), 4);

    fuelSystem.startBurn(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);

    // Advance time by 3 hours
    vm.warp(block.timestamp + (3600 * 3) + 100);

    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 100);
    assertEq(FuelConsumptionState.getBurnState(smartObjectId), true);

    //deposit fuel of different type during last unit should fail
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_ActiveFuelCycleExists.selector, smartObjectId, fuelSmartObjectId2)
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId2, 1);

    //Try to deposit fuel of different type after burn stopped, but previous cycle is not completed
    fuelSystem.stopBurn(smartObjectId);
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_ActiveFuelCycleExists.selector, smartObjectId, fuelSmartObjectId2)
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId2, 1);

    //same type should work
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 1);
    assertEq(Fuel.getFuelAmount(smartObjectId), 1);

    vm.stopPrank();
  }

  function test_fuelEfficiencyImpact() public {
    vm.startPrank(deployer);

    // Setup with 50% efficiency
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 50);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );

    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId);

    // Verify initial state
    (, , uint256 actualRate, uint256 fuelAmount) = fuelSystem.getCurrentFuelConsumptionStatus(smartObjectId);
    assertTrue(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(fuelAmount, 4);
    assertEq(actualRate, 1800); // 50% of 3600

    // Advance time by 1 hour
    vm.warp(block.timestamp + 3600);

    fuelSystem.updateFuel(smartObjectId);
    // Check state - should have consumed 2 units (due to 50% efficiency)
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);

    vm.stopPrank();
  }

  function test_outOfFuelHandling() public {
    vm.startPrank(deployer);

    // Setup with minimal fuel
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 2);
    fuelSystem.startBurn(smartObjectId);

    // Advance time beyond available fuel
    vm.warp(block.timestamp + 7200);

    fuelSystem.updateFuel(smartObjectId);

    // Verify system stopped burning when out of fuel
    assertFalse(FuelConsumptionState.getBurnState(smartObjectId), "Burn state should be false");
    assertEq(Fuel.getFuelAmount(smartObjectId), 0, "Fuel amount should be 0");
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0, "Elapsed time should be 0");

    vm.stopPrank();
  }

  //check fuel unit at every interval
  function test_fuelUnitAtEveryInterval() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 900 })
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00 AM

    assertEq(
      Fuel.getFuelAmount(smartObjectId),
      4,
      "On Start Burn, 1 unit of fuel should be consumed and it should be 4"
    );
    assertEq(FuelConsumptionState.getBurnState(smartObjectId), true);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp);

    // Advance time by 600 seconds
    vm.warp(block.timestamp + 600); //10:10 AM
    fuelSystem.updateFuel(smartObjectId);

    assertEq(
      Fuel.getFuelAmount(smartObjectId),
      4,
      "After updateFuel, fuel amount should still be 4 as it is not consumed yet"
    );
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 600);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 600, "After updateFuel, elapsed time should be 600");

    // Advance time by 400 seconds
    vm.warp(block.timestamp + 400); //10:16 AM

    (uint256 elapsedTime, uint256 unitsToConsume, uint256 actualBurnRate, uint256 fuelAmount) = fuelSystem
      .getCurrentFuelConsumptionStatus(smartObjectId);
    assertEq(elapsedTime, 100);
    assertEq(unitsToConsume, 1);
    assertEq(actualBurnRate, 900);
    assertEq(fuelAmount, 4);

    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 3, "After updateFuel, fuel amount should be 3");
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 100);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 100, "After fuel consumption, elapsed time is 100");

    //Advance time to consume 4 units of fuel, last unit is being consumed
    vm.warp(block.timestamp + 2700);
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0, "After updateFuel, fuel amount should be 0");
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 100, "After updateFuel, elapsed time should be 100");
    assertEq(FuelConsumptionState.getBurnState(smartObjectId), true, "After updateFuel, burn state should be true");

    vm.warp(block.timestamp + 900);
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0, "After updateFuel, fuel amount should be 0");
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0, "After updateFuel, elapsed time should be 100");
    assertEq(FuelConsumptionState.getBurnState(smartObjectId), false, "After updateFuel, burn state should be false");

    vm.stopPrank();
  }

  function test_stopStartBurnCycle() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00

    assertEq(Fuel.getFuelAmount(smartObjectId), 4);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    // Advance 15 minutes and stop burn
    vm.warp(block.timestamp + 900); //10:15
    fuelSystem.stopBurn(smartObjectId);

    assertEq(FuelConsumptionState.getBurnState(smartObjectId), false);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    // Advance 15 minutes and start burn again
    vm.warp(block.timestamp + 900); //10:30
    fuelSystem.startBurn(smartObjectId);

    assertEq(FuelConsumptionState.getBurnState(smartObjectId), true);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    // Advance 15 minutes and update fuel
    vm.warp(block.timestamp + 900); //10:45
    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 4);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 900);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 1800);

    vm.warp(block.timestamp + 1900); //11:16

    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);
    (uint256 elapsedTime, uint256 unitsToConsume, uint256 actualBurnRate, uint256 fuelAmount) = fuelSystem
      .getCurrentFuelConsumptionStatus(smartObjectId);
    assertEq(elapsedTime, 100);
    assertEq(unitsToConsume, 1);
    assertEq(actualBurnRate, 3600);
    assertEq(fuelAmount, 4);

    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 3);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 100);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 100);

    vm.stopPrank();
  }

  function test_cronJobFailure() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 })
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00

    // Skip updates for 2 hours
    vm.warp(block.timestamp + 7200); //12:00
    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp);

    vm.stopPrank();
  }

  function test_longIntervalBetweenUpdates() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 900 }) //15 minutes
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 10);
    fuelSystem.startBurn(smartObjectId); //10:00

    // Update after 15 minutes
    vm.warp(block.timestamp + 900); //10:15
    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 8);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    // Skip update for 1 hour 45 minutes
    vm.warp(block.timestamp + 6700); //12:03
    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 1);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 400);

    vm.stopPrank();
  }

  function test_multipleStopStartCycles() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 1800 }) //30 minutes
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00

    // First stop/start cycle
    vm.warp(block.timestamp + 900); //10:15
    fuelSystem.stopBurn(smartObjectId);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);

    vm.warp(block.timestamp + 900); //10:30
    fuelSystem.startBurn(smartObjectId);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 900);

    vm.warp(block.timestamp + 900); //10:45
    fuelSystem.stopBurn(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 4);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 900); //11:00
    fuelSystem.startBurn(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 900); //11:15

    fuelSystem.updateFuel(smartObjectId);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 900);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 900);

    vm.warp(block.timestamp + 900); //11:30
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 1800); //12.00
    fuelSystem.stopBurn(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    fuelSystem.startBurn(smartObjectId); //12.00
    assertEq(Fuel.getFuelAmount(smartObjectId), 1);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 1900); //12:31
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 100);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), block.timestamp - 100);

    vm.warp(block.timestamp + 500); //12:31

    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 0);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 600);

    vm.warp(block.timestamp + 1200); //12:51
    fuelSystem.updateFuel(smartObjectId);

    assertEq(Fuel.getFuelAmount(smartObjectId), 0);
    assertEq(FuelConsumptionState.getBurnStartTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getPreviousCycleElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);
    assertEq(FuelConsumptionState.getBurnState(smartObjectId), false);

    vm.stopPrank();
  }

  function test_veryShortBurnRate() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 60 }) //1 minute
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00

    vm.warp(block.timestamp + 60); //10:01
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 60); //10:02
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.stopPrank();
  }

  function test_veryLongBurnRate() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 86400 }) //24 hours
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 3);
    fuelSystem.startBurn(smartObjectId); //10:00

    vm.warp(block.timestamp + 7200); //12:00
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 7200);

    vm.warp(block.timestamp + 43200);
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 2);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 50400);

    vm.warp(block.timestamp + 37000);
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 1);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 1000);

    vm.stopPrank();
  }

  function test_partialUnitConsumption() public {
    vm.startPrank(deployer);
    fuelSystem.configureFuelEfficiency(fuelSmartObjectId, fuelEntityRecordParams, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({ fuelMaxCapacity: 10000, fuelBurnRateInSeconds: 3600 }) //1 hour
    );
    fuelSystem.depositFuel(smartObjectId, fuelSmartObjectId, 5);
    fuelSystem.startBurn(smartObjectId); //10:00

    vm.warp(block.timestamp + 1800); //10:30
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 4);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 1800);

    vm.warp(block.timestamp + 1800); //11:00
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 0);

    vm.warp(block.timestamp + 1800); //11:30
    fuelSystem.updateFuel(smartObjectId);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);
    assertEq(FuelConsumptionState.getElapsedTime(smartObjectId), 1800);

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
}
