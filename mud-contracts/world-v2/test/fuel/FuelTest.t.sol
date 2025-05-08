// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { FuelParams } from "../../src/namespaces/evefrontier/systems/fuel/types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

// Create a mock system to properly test system-to-system calls
contract MockFuelInteractSystem is System {
  function callConfigureFuelParameters(uint256 smartObjectId, FuelParams memory fuelParams) public {
    fuelSystem.configureFuelParameters(smartObjectId, fuelParams);
  }

  function callConfigureFuelEfficiency(uint256 fuelTypeId, uint256 fuelEfficiency) public {
    fuelSystem.configureFuelEfficiency(fuelTypeId, fuelEfficiency);
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

  // Bounds for fuelBurnRateInSeconds
  uint256 constant MIN_FUEL_BURN_RATE = 60;
  uint256 constant MAX_FUEL_BURN_RATE = type(uint128).max;

  // Bounds for fuelAmount
  uint256 constant MAX_FUEL_AMOUNT = type(uint128).max / ONE_UNIT_IN_WEI;

  // Bounds for fuelMaxCapacity
  uint256 constant MAX_FUEL_MAX_CAPACITY = type(uint128).max;

  uint256 constant TEST_FUEL_TYPE_ID = 1;

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

    location = LocationData({ solarSystemId: 1, x: 1000, y: 1001, z: 1002 });

    vm.stopPrank();
    vm.resumeGasMetering();
  }

  function test_configureFuelParameters() public {
    vm.startPrank(deployer);

    // Configure fuel efficiency first
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 100);

    // Test valid configuration
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

    // Verify configuration
    assertEq(Fuel.getFuelTypeId(smartObjectId), TEST_FUEL_TYPE_ID);
    assertEq(Fuel.getFuelUnitVolume(smartObjectId), 1000);
    assertEq(Fuel.getFuelMaxCapacity(smartObjectId), 10000);
    assertEq(Fuel.getFuelBurnRateInSeconds(smartObjectId), 3600);
    assertEq(Fuel.getFuelAmount(smartObjectId), 5);

    // Test invalid configurations
    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelTypeId.selector,
        smartObjectId,
        0,
        1,
        uint256(type(uint128).max)
      )
    );
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: 0,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelUnitVolume.selector,
        smartObjectId,
        0,
        1,
        uint256(type(uint128).max)
      )
    );
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 0,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        FuelSystem.Fuel_InvalidFuelMaxCapacity.selector,
        smartObjectId,
        0,
        1,
        uint256(type(uint128).max)
      )
    );
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 0,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

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
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 30,
        fuelAmount: 5
      })
    );

    vm.stopPrank();
  }

  function test_configureFuelEfficiency() public {
    vm.startPrank(deployer);

    // Test valid configuration
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 80);
    assertEq(FuelEfficiencyConfig.getEfficiency(TEST_FUEL_TYPE_ID), 80);

    // Test invalid configurations
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelTypeId.selector, 0, 80, 1, uint256(type(uint128).max))
    );
    fuelSystem.configureFuelEfficiency(0, 80); // Invalid fuel type

    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelEfficiency.selector, TEST_FUEL_TYPE_ID, 101, 10, 100)
    );
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 101); // Efficiency > 100

    vm.stopPrank();
  }

  function test_depositAndWithdrawFuel() public {
    vm.startPrank(deployer);

    // Setup initial configuration
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 0
      })
    );

    // Test deposit
    fuelSystem.depositFuel(smartObjectId, 5);
    assertEq(Fuel.getFuelAmount(smartObjectId), 5);

    // Test withdraw
    fuelSystem.withdrawFuel(smartObjectId, 2);
    assertEq(Fuel.getFuelAmount(smartObjectId), 3);

    // Test invalid operations
    vm.expectRevert(
      abi.encodeWithSelector(FuelSystem.Fuel_ExceedsMaxCapacity.selector, smartObjectId, 8, 11000, 10000)
    );
    fuelSystem.depositFuel(smartObjectId, 8); // Would exceed max capacity

    vm.expectRevert(abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelAmount.selector, smartObjectId, 4, 1, 3));
    fuelSystem.withdrawFuel(smartObjectId, 4); // Not enough fuel

    vm.expectRevert(abi.encodeWithSelector(FuelSystem.Fuel_InvalidFuelAmount.selector, smartObjectId, 0, 1, 3));
    fuelSystem.withdrawFuel(smartObjectId, 0); // Cannot withdraw 0

    vm.stopPrank();
  }

  function test_burnFunctionality() public {
    vm.startPrank(deployer);

    // Setup initial configuration
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

    // Start burn
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

    // Stop burn
    fuelSystem.stopBurn(smartObjectId);

    // Verify burn stopped
    assertFalse(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(FuelConsumptionState.getFuelConsumptionTimeRemaining(smartObjectId), 0);
  }

  function test_fuelEfficiencyImpact() public {
    vm.startPrank(deployer);

    // Setup with 50% efficiency
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 50);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 5
      })
    );

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
    fuelSystem.configureFuelEfficiency(TEST_FUEL_TYPE_ID, 100);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      FuelParams({
        fuelTypeId: TEST_FUEL_TYPE_ID,
        fuelUnitVolume: 1000,
        fuelMaxCapacity: 10000,
        fuelBurnRateInSeconds: 3600,
        fuelAmount: 2
      })
    );
    fuelSystem.startBurn(smartObjectId);

    // Advance time beyond available fuel
    vm.warp(block.timestamp + 7200);

    fuelSystem.updateFuel(smartObjectId);

    // Verify system stopped burning when out of fuel
    assertFalse(FuelConsumptionState.getBurnState(smartObjectId));
    assertEq(Fuel.getFuelAmount(smartObjectId), 0);
    assertEq(FuelConsumptionState.getFuelConsumptionTimeRemaining(smartObjectId), 0);

    vm.stopPrank();
  }

  //TODO : System to system calls with mock system

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
