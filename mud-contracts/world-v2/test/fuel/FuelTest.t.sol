// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { Fuel } from "../../src/codegen/index.sol";
import { IFuelSystem } from "../../src/codegen/world/IFuelSystem.sol";
import { FuelSystem } from "../../src/systems/fuel/FuelSystem.sol";
import { Fuel, FuelData } from "../../src/codegen/tables/Fuel.sol";
import { SmartDeployableSystem } from "../../src/systems/smart-deployable/SmartDeployableSystem.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { State, SmartObjectData } from "../../src/systems/smart-deployable/types.sol";
import { Location, LocationData } from "../../src/codegen/tables/Location.sol";

import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";
import { FuelUtils } from "../../src/systems/fuel/FuelUtils.sol";

import { DECIMALS } from "../../src/systems/smart-deployable/constants.sol";

contract FuelTest is MudTest {
  IBaseWorld world;
  using FuelUtils for bytes14;

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);
  }

  function testWorldExists() public {
    uint256 codeSize;
    address addr = worldAddress;
    assembly {
      codeSize := extcodesize(addr)
    }
    assertTrue(codeSize > 0);
  }

  function testSetFuel(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 lastUpdatedAt
  ) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();

    world.call(
      systemId,
      abi.encodeCall(
        FuelSystem.configureFuelParameters,
        (smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount, lastUpdatedAt)
      )
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  function testGetFuel(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 lastUpdatedAt
  ) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(
      systemId,
      abi.encodeCall(
        FuelSystem.configureFuelParameters,
        (smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount, lastUpdatedAt)
      )
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  function testSetFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelUnitVolume, (smartObjectId, fuelUnitVolume)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelUnitVolume, fuel.fuelUnitVolume);
  }

  function testSetFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(
      systemId,
      abi.encodeCall(FuelSystem.setFuelConsumptionIntervalInSeconds, (smartObjectId, fuelConsumptionIntervalInSeconds))
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelConsumptionIntervalInSeconds, fuel.fuelConsumptionIntervalInSeconds);
  }

  function testSetFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelMaxCapacity, (smartObjectId, fuelMaxCapacity)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelMaxCapacity, fuel.fuelMaxCapacity);
  }

  function testSetFuelAmount(uint256 smartObjectId, uint256 fuelAmount) public {
    vm.assume(smartObjectId != 0);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelAmount, (smartObjectId, fuelAmount)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  function testDepositFuel(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location,
    uint256 fuelAmount
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelAmount != 0);
    vm.assume(fuelAmount < type(uint64).max);
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelAmount * fuelUnitVolume < fuelMaxCapacity);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(systemId, abi.encodeCall(FuelSystem.depositFuel, (entityId, fuelAmount)));

    FuelData memory fuelData = Fuel.get(entityId);

    assertEq(fuelData.fuelAmount, fuelAmount * (10 ** DECIMALS));
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testDepositFuelTwice(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelAmount < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelAmount * fuelUnitVolume * 2 < fuelMaxCapacity);

    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity,
      location,
      fuelAmount
    );

    ResourceId systemId = FuelUtils.fuelSystemId();
    world.call(systemId, abi.encodeCall(FuelSystem.depositFuel, (entityId, fuelAmount)));

    FuelData memory fuelData = Fuel.get(entityId);

    assertEq(fuelData.fuelAmount, fuelAmount * 2 * (10 ** DECIMALS));
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  // test fuel consumption
  function testFuelConsumption(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(fuelAmount < type(uint64).max);
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds

    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes

    vm.assume(fuelAmount * (10 ** DECIMALS) > fuelConsumption);

    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      location,
      fuelAmount
    );

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.bringOnline, (entityId)));

    vm.warp(block.timestamp + timeElapsed);

    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (entityId)));

    FuelData memory fuelData = Fuel.get(entityId);

    assertEq(fuelData.fuelAmount, fuelAmount * (10 ** DECIMALS) - fuelConsumption);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumptionRunsOut(
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    fuelAmount %= 1000000;
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionIntervalInSeconds > 3600 && fuelConsumptionIntervalInSeconds < (24 * 3600)); // relatively high consumption
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds

    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount * (10 ** DECIMALS) < fuelConsumption);

    uint256 entityId = 1;
    LocationData memory location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    testDepositFuel(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      UINT256_MAX,
      location,
      fuelAmount
    );

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.bringOnline, (entityId)));

    vm.warp(block.timestamp + timeElapsed);
    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (entityId)));

    FuelData memory fuelData = Fuel.get(entityId);

    assertEq(fuelData.fuelAmount, 0);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testFuelRefundDuringGlobalOffline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    LocationData memory location,
    uint256 fuelAmount,
    uint256 timeElapsedBeforeOffline,
    uint256 globalOfflineDuration,
    uint256 timeElapsedAfterOffline
  ) public {
    vm.assume(fuelAmount < type(uint32).max);
    vm.assume(fuelUnitVolume < type(uint128).max);
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsedBeforeOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(timeElapsedAfterOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(globalOfflineDuration < 7 days); // Example constraint: timeElapsed is less than 7 days in seconds

    uint256 fuelConsumption = ((timeElapsedBeforeOffline * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS));
    fuelConsumption += ((timeElapsedAfterOffline * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds);

    vm.assume(fuelAmount * (10 ** DECIMALS) > fuelConsumption); // this time we want to run out of fuel
    vm.assume(smartObjectData.owner != address(0));

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.globalResume, ()));

    world.call(
      deployableSystemId,
      abi.encodeCall(
        SmartDeployableSystem.registerDeployable,
        (entityId, smartObjectData, fuelUnitVolume, fuelConsumptionIntervalInSeconds, UINT256_MAX)
      )
    );

    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelMaxCapacity, (entityId, UINT256_MAX)));
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.depositFuel, (entityId, fuelAmount)));

    // anchor smart deployable
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.anchor, (entityId, location)));
    // bring online
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.bringOnline, (entityId)));
    vm.warp(block.timestamp + timeElapsedBeforeOffline);
    // global pause
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.globalPause, ()));
    vm.warp(block.timestamp + globalOfflineDuration);
    // global resume
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.globalResume, ()));
    vm.warp(block.timestamp + timeElapsedAfterOffline);
    // update fuel
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (entityId)));

    // get fuel data
    FuelData memory fuelData = Fuel.get(entityId);

    assertEq((fuelData.fuelAmount) / 1e18, (fuelAmount * (10 ** DECIMALS) - fuelConsumption) / 1e18);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(entityId)));
  }

  // ******** HELPER FUNCTIONS TO TEST FUEL SYSTEM ******** //

  function testRegisterDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionIntervalInSeconds != 0);
    vm.assume(fuelMaxCapacity != 0);
    vm.assume(smartObjectData.owner != address(0));

    ResourceId systemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(systemId, abi.encodeCall(SmartDeployableSystem.globalResume, ()));

    DeployableStateData memory data = DeployableStateData({
      createdAt: block.timestamp,
      previousState: State.NULL,
      currentState: State.UNANCHORED,
      isValid: true,
      anchoredAt: block.timestamp,
      updatedBlockNumber: block.number,
      updatedBlockTime: block.timestamp
    });

    world.call(
      systemId,
      abi.encodeCall(
        SmartDeployableSystem.registerDeployable,
        (entityId, smartObjectData, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity)
      )
    );

    DeployableStateData memory tableData = DeployableState.get(entityId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.currentState), uint8(tableData.currentState));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  function testAnchor(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(entityId != 0);
    testRegisterDeployable(
      entityId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.anchor, (entityId, location)));

    LocationData memory tableData = Location.get(entityId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }
}
