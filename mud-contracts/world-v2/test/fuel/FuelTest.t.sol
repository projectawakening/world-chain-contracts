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
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { State, SmartObjectData } from "../../src/systems/deployable/types.sol";
import { Location, LocationData } from "../../src/codegen/tables/Location.sol";

import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";
import { FuelUtils } from "../../src/systems/fuel/FuelUtils.sol";

import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/systems/constants.sol";

import { DeployableTest } from "../deployable/DeployableTest.t.sol";

import "forge-std/console.sol";

contract FuelTest is DeployableTest {
  LocationData location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });
  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);
  }

  function testSetFuel(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelUnitVolume != 0 && fuelUnitVolume < type(uint128).max);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);
    vm.assume(fuelAmount != 0 && fuelAmount < type(uint128).max);
    vm.assume((fuelAmount * ONE_UNIT_IN_WEI) < type(uint64).max / 2);
    vm.assume(fuelMaxCapacity > (fuelAmount * fuelUnitVolume));

    world.call(
      fuelSystemId,
      abi.encodeCall(
        FuelSystem.configureFuelParameters,
        (smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount)
      )
    );

    FuelData memory fuel = Fuel.get(smartObjectId);
    assertEq(fuelAmount * ONE_UNIT_IN_WEI, fuel.fuelAmount);
  }

  function testSetFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    vm.assume(smartObjectId != 0);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelUnitVolume, (smartObjectId, fuelUnitVolume)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelUnitVolume, fuel.fuelUnitVolume);
  }

  function testSetFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public {
    vm.assume(smartObjectId != 0);
    world.call(
      fuelSystemId,
      abi.encodeCall(FuelSystem.setFuelConsumptionIntervalInSeconds, (smartObjectId, fuelConsumptionIntervalInSeconds))
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelConsumptionIntervalInSeconds, fuel.fuelConsumptionIntervalInSeconds);
  }

  function testSetFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    vm.assume(smartObjectId != 0);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.setFuelMaxCapacity, (smartObjectId, fuelMaxCapacity)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelMaxCapacity, fuel.fuelMaxCapacity);
  }

  function testDepositFuel(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount > 0);
    vm.assume(fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume((fuelAmount * fuelUnitVolume) < fuelMaxCapacity);
    vm.assume(fuelMaxCapacity > (fuelAmount * fuelUnitVolume));
    vm.assume(fuelConsumptionIntervalInSeconds > 60); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    testAnchor(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.depositFuel, (smartObjectId, fuelAmount)));

    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, fuelAmount * ONE_UNIT_IN_WEI);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testDepositFuelTwice(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelAmount * fuelUnitVolume * 2 < fuelMaxCapacity);

    testDepositFuel(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.depositFuel, (smartObjectId, fuelAmount)));

    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, fuelAmount * 2 * ONE_UNIT_IN_WEI);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumption(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount != 0);
    vm.assume(fuelAmount < type(uint64).max);
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount * (10 ** DECIMALS) > fuelConsumption);

    testDepositFuel(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOnline, (smartObjectId)));

    vm.warp(block.timestamp + timeElapsed);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (smartObjectId)));

    FuelData memory fuelData = Fuel.get(smartObjectId);
    assertEq(fuelData.fuelAmount, fuelAmount * (10 ** DECIMALS) - fuelConsumption);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  // test fuel runs out
  function testFuelConsumptionRunsOut(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    fuelAmount %= 1000000;
    vm.assume(fuelUnitVolume < type(uint64).max);
    vm.assume(fuelConsumptionIntervalInSeconds > 3600 && fuelConsumptionIntervalInSeconds < (24 * 3600)); // relatively high consumption
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds

    uint256 fuelConsumption = ((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) +
      (1 * ONE_UNIT_IN_WEI); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount * ONE_UNIT_IN_WEI < fuelConsumption);

    uint256 smartObjectId = 1;

    testDepositFuel(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, UINT256_MAX, fuelAmount);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOnline, (smartObjectId)));

    vm.warp(block.timestamp + timeElapsed);
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (smartObjectId)));

    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, 0);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testFuelRefundDuringGlobalOffline(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelAmount,
    uint256 timeElapsedBeforeOffline,
    uint256 globalOfflineDuration,
    uint256 timeElapsedAfterOffline
  ) public {
    vm.assume(smartObjectId != 0);
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

    testDepositFuel(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, UINT256_MAX, fuelAmount);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOnline, (smartObjectId)));

    vm.warp(block.timestamp + timeElapsedBeforeOffline);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalPause, ()));
    vm.warp(block.timestamp + globalOfflineDuration);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));
    vm.warp(block.timestamp + timeElapsedAfterOffline);

    world.call(fuelSystemId, abi.encodeCall(FuelSystem.updateFuel, (smartObjectId)));

    FuelData memory data = Fuel.get(smartObjectId);

    assertEq((data.fuelAmount) / 1e18, (fuelAmount * (10 ** DECIMALS) - fuelConsumption) / 1e18);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  }
}
