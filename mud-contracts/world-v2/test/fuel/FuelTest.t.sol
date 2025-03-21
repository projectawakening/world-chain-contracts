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
import { 
  GlobalDeployableState, 
  Inventory, 
  Tenant, 
  EntityRecord, 
  EntityRecordData,
  DeployableState, 
  DeployableStateData, 
  InventoryItemData, 
  InventoryItem,
  InventoryByItem,
  OwnershipByObject,
  EphemeralInvCapacity,
  CharactersByAccount,
  LocationData,
  EphemeralInventory,
  EphemeralInvItem,
  ObjectByEphemeral,
  SmartAssembly,
  SmartAssemblyData,
  Fuel,
  FuelData,
  Location,
  LocationData
} from "../../src/namespaces/evefrontier/codegen/index.sol";
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
import { InventoryItemParams } from "../../src/namespaces/evefrontier/systems/inventory/types.sol";
import { State } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { CreateAndAnchorParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

// Create a mock system to properly test system-to-system calls
contract MockFuelInteractSystem is System {

  function callConfigureFuelParameters(uint256 smartObjectId, uint256 fuelUnitVolume, uint256 fuelConsumptionIntervalInSeconds, uint256 fuelMaxCapacity, uint256 fuelAmount) public {
    fuelSystem.configureFuelParameters(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount);
  }
  
  function callSetFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    fuelSystem.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
  }
  
  function callSetFuelConsumptionIntervalInSeconds(uint256 smartObjectId, uint256 fuelConsumptionIntervalInSeconds) public {
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
  address bob;

  LocationData location;

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
    tenantId = keccak256(abi.encodePacked("TEST"));
    
    // Setup smart object ID
    smartObjectId = _calculateObjectId(SMART_OBJECT_ID, SMART_OBJECT_TYPE_ID, true);
    
    // Register class and setup smart object state
    deployableObjectClassId = uint256(keccak256(abi.encodePacked(tenantId, SMART_OBJECT_TYPE_ID)));

    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("evefrontier");
    bytes16 name = bytes16("MockFuelInteract"); 
    fuelMockSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);
    
    // Deploy and register the mock system
    fuelMockSystem = new MockFuelInteractSystem();
    
    // Register the system with the world
    world.registerSystem(fuelMockSystemId, fuelMockSystem, true);

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

    location = LocationData({
      solarSystemId: 1,
      x: 1000,
      y: 1001,
      z: 1002
    });
    
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
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);
    // if (fuelUnitVolume == 0 || fuelUnitVolume > uint256(type(uint128).max)) {
    //   revert Fuel_InvalidFuelUnitVolume(smartObjectId, fuelUnitVolume, 1, uint256(type(uint128).max));
    // }
    // if (fuelConsumptionIntervalInSeconds <= 1 || fuelConsumptionIntervalInSeconds > (type(uint256).max / ONE_UNIT_IN_WEI)) {
    //   revert Fuel_InvalidFuelConsumptionInterval(smartObjectId, fuelConsumptionIntervalInSeconds, 1, (type(uint256).max / ONE_UNIT_IN_WEI));
    // }
    // if (fuelAmount * ONE_UNIT_IN_WEI > uint256(type(uint128).max)) {
    //   revert Fuel_InvalidFuelAmount(smartObjectId, fuelAmount, 0, uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    // }
    // if (fuelMaxCapacity < fuelAmount * fuelUnitVolume || fuelUnitVolume >= fuelMaxCapacity) {
    //   revert Fuel_InvalidFuelMaxCapacity(smartObjectId, fuelMaxCapacity, fuelAmount == 0 ? fuelUnitVolume + 1 : fuelAmount * fuelUnitVolume, uint256(type(uint256).max));
    // }
    // Create and anchor deployable
    vm.startPrank(alice, deployer);
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));
    vm.stopPrank();

    assertEq(fuelUnitVolume, Fuel.getFuelUnitVolume(smartObjectId));
    assertEq(fuelConsumptionIntervalInSeconds, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
    assertEq(fuelMaxCapacity, Fuel.getFuelMaxCapacity(smartObjectId));
    assertEq(0, Fuel.getFuelAmount(smartObjectId));

    vm.startPrank(deployer);
    // Configure fuel parameters
    fuelSystem.configureFuelParameters(
      smartObjectId,
      fuelUnitVolume + 1,
      fuelConsumptionIntervalInSeconds + 1,
      fuelMaxCapacity + 1,
      fuelAmount + 1
    );
    vm.stopPrank();

    assertEq(fuelUnitVolume + 1, Fuel.getFuelUnitVolume(smartObjectId));
    assertEq(fuelConsumptionIntervalInSeconds + 1, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
    assertEq(fuelMaxCapacity + 1, Fuel.getFuelMaxCapacity(smartObjectId));
    assertEq((fuelAmount + 1) * ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
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
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);
    
    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));
    vm.stopPrank();

    assertEq(fuelUnitVolume, Fuel.getFuelUnitVolume(smartObjectId));

    vm.startPrank(deployer);
    // Set fuel unit volume
    fuelSystem.setFuelUnitVolume(smartObjectId, fuelUnitVolume + 1);
    vm.stopPrank();

    assertEq(fuelUnitVolume + 1, Fuel.getFuelUnitVolume(smartObjectId));
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
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));
    vm.stopPrank();

    assertEq(fuelConsumptionIntervalInSeconds, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));

    vm.startPrank(deployer);
    // Set fuel consumption interval in seconds
    fuelSystem.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds + 1);
    vm.stopPrank();

    assertEq(fuelConsumptionIntervalInSeconds + 1, Fuel.getFuelConsumptionIntervalInSeconds(smartObjectId));
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
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));
    vm.stopPrank();

    assertEq(fuelMaxCapacity, Fuel.getFuelMaxCapacity(smartObjectId));

    vm.startPrank(deployer);
    fuelSystem.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity + 1);
    vm.stopPrank();

    assertEq(fuelMaxCapacity + 1, Fuel.getFuelMaxCapacity(smartObjectId));
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
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));

    assertEq(0, Fuel.getFuelAmount(smartObjectId));
    
    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI && fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI);

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
    vm.assume(fuelAmount > 0 && fuelAmount < uint256(type(uint128).max) / ( 2 * ONE_UNIT_IN_WEI)); // deposit twice so deivide by 2
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));

    assertEq(0, Fuel.getFuelAmount(smartObjectId));

    // requirement specifically for depositFuel * 2
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(fuelAmount < uint256(type(uint128).max) / (2 * ONE_UNIT_IN_WEI) && fuelAmount < ((fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI) / 2);

    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    deployableSystem.bringOnline(smartObjectId);

    assertEq((fuelAmount * ONE_UNIT_IN_WEI) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
    
    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    vm.stopPrank();

    assertEq((fuelAmount * ONE_UNIT_IN_WEI * 2) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));
    assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  }

  function testFuelConsumption(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1);
    uint256 fuelConsumption = ((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) + (1 * ONE_UNIT_IN_WEI); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount > fuelConsumption && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
    vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

    vm.startPrank(alice, deployer);
    // Create and anchor deployable
    deployableSystem.createAndAnchor(CreateAndAnchorParams(
      smartObjectId,
      "SSU",
      EntityRecordParams({
        tenantId: tenantId,
        typeId: SMART_OBJECT_TYPE_ID,
        itemId: SMART_OBJECT_ID,
        volume: 1000
      }),
      alice,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location
    ));

    // requirement specifically for depositFuel
    uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
    vm.assume(fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI && fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI);

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

  // // test fuel runs out
  // function testFuelConsumptionRunsOut(
  //   uint256 fuelUnitVolume,
  //   uint256 fuelConsumptionIntervalInSeconds,
  //   uint256 fuelMaxCapacity,
  //   uint256 fuelAmount,
  //   uint256 timeElapsed
  // ) public {
  //   vm.assume(timeElapsed > 5 days && timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
  //   vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
  //   vm.assume(fuelConsumptionIntervalInSeconds == 1); // relatively high consumption rate, 10 second tick
  //   uint256 fuelConsumption = ((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) + (1 * ONE_UNIT_IN_WEI); // bringing online consumes exactly one wei's worth of gas for tick purposes
  //   vm.assume(fuelAmount < fuelConsumption && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
  //   vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity > fuelUnitVolume && fuelMaxCapacity < type(uint256).max);

  //   vm.startPrank(alice, deployer);
  //   // Create and anchor deployable
  //   deployableSystem.createAndAnchor(CreateAndAnchorParams(
  //     smartObjectId,
  //     "SSU",
  //     EntityRecordParams({
  //       tenantId: tenantId,
  //       typeId: SMART_OBJECT_TYPE_ID,
  //       itemId: SMART_OBJECT_ID,
  //       volume: 1000
  //     }),
  //     alice,
  //     fuelUnitVolume,
  //     fuelConsumptionIntervalInSeconds,
  //     fuelMaxCapacity,
  //     location
  //   ));

  //   // requirement specifically for depositFuel
  //   uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
  //   vm.assume(fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI && fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI);

  //   fuelSystem.depositFuel(smartObjectId, fuelAmount);
  //   deployableSystem.bringOnline(smartObjectId);
  //   vm.stopPrank();

  //   assertEq((fuelAmount * ONE_UNIT_IN_WEI) - ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));

  //   vm.startPrank(deployer);
  //   vm.warp(block.timestamp + timeElapsed);
  //   fuelSystem.updateFuel(smartObjectId);
  //   vm.stopPrank();

  //   assertEq(0, Fuel.getFuelAmount(smartObjectId));
  //   assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  //   assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  // }

  // function testFuelRefundDuringGlobalOffline(
  //   uint256 fuelUnitVolume,
  //   uint256 fuelConsumptionIntervalInSeconds,
  //   uint256 fuelMaxCapacity,
  //   uint256 fuelAmount,
  //   uint256 timeElapsedBeforeOffline,
  //   uint256 globalOfflineDuration,
  //   uint256 timeElapsedAfterOffline
  // ) public {
  //   vm.assume(fuelUnitVolume < fuelMaxCapacity && fuelUnitVolume > 0 && fuelUnitVolume < uint256(type(uint128).max));
  //   vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 60); 
  //   vm.assume(fuelAmount > 1 && fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI);
  //   vm.assume(fuelMaxCapacity > fuelAmount * fuelUnitVolume && fuelMaxCapacity < type(uint256).max);
    
  //   vm.assume(timeElapsedBeforeOffline < 1 * 365 days); // Example constraint: timeElapsed is less than 1 year in seconds
  //   vm.assume(timeElapsedAfterOffline < 1 * 365 days); // Example constraint: timeElapsed is less than 1 year in seconds
  //   vm.assume(globalOfflineDuration < 7 days); // Example constraint: timeElapsed is less than 7 days in seconds
    
  //   uint256 fuelConsumption = ((timeElapsedBeforeOffline * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) + (1 * ONE_UNIT_IN_WEI);
  //   fuelConsumption += ((timeElapsedAfterOffline * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds);
  //   vm.assume(fuelAmount * ONE_UNIT_IN_WEI > fuelConsumption); // this time we want to run out of fuel, so big fuelAmount

  //   vm.startPrank(alice, deployer);
  //   deployableSystem.anchor(smartObjectId, alice, location);

  //   // requirement specifically for depositFuel
  //   uint256 currentFuelAmount = Fuel.getFuelAmount(smartObjectId);
  //   vm.assume(fuelAmount < uint256(type(uint128).max) / ONE_UNIT_IN_WEI && fuelAmount < (fuelMaxCapacity / fuelUnitVolume) - currentFuelAmount / ONE_UNIT_IN_WEI);

  //   fuelSystem.depositFuel(smartObjectId, fuelAmount);
  //   deployableSystem.bringOnline(smartObjectId);
  //   vm.stopPrank();

  //   assertEq(fuelAmount * ONE_UNIT_IN_WEI, Fuel.getFuelAmount(smartObjectId));

  //   vm.warp(block.timestamp + timeElapsedBeforeOffline);
  //   deployableSystem.globalPause();
  //   vm.warp(block.timestamp + globalOfflineDuration);
  //   deployableSystem.globalResume();
  //   vm.warp(block.timestamp + timeElapsedAfterOffline);

  //   fuelSystem.updateFuel(smartObjectId);
  //   vm.stopPrank();

  //   uint256 amount = Fuel.getFuelAmount(smartObjectId);

  //   // Round values to nearest whole number before comparison
  //   uint256 expectedAmount = ((fuelAmount * (10 ** DECIMALS) - fuelConsumption) / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;
  //   uint256 actualAmount = (amount / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;

  //   assertEq(actualAmount, expectedAmount);
  //   assertEq(block.timestamp, Fuel.getLastUpdatedAt(smartObjectId));
  //   assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  // }

  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    
    if (itemId != 0) { // For singleton items
      EntityRecord.set(entityId, true, tenantId, itemId, typeId, volume);

      if (!EntityRecord.getExists(classId)) {
        EntityRecord.set(classId, true, tenantId, 0, typeId, volume);
      }
    } else { // For non-singleton items
      EntityRecord.set(classId, true, tenantId, 0, typeId, volume);
    }
    
    if (!Entity.getExists(classId)) {
      entitySystem.registerClass(classId, new ResourceId[](0));
    }
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 itemId, uint256 typeId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
