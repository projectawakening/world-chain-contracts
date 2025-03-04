// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { Fuel } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { FuelSystem } from "../../src/namespaces/evefrontier/systems/fuel/FuelSystem.sol";
import { Fuel, FuelData } from "../../src/namespaces/evefrontier/codegen/tables/Fuel.sol";
import { DeployableSystem } from "../../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { Location, LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";

import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";

import { DECIMALS, ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";

import { DeployableTest } from "../deployable/DeployableTest.t.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

contract FuelTest is DeployableTest {
  LocationData location = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

  function setUp() public virtual override {
    super.setUp();
  }

  function testSetFuel(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelUnitVolume != 0 && fuelUnitVolume < type(uint128).max);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);
    vm.assume(fuelAmount != 0 && fuelAmount < type(uint128).max);
    vm.assume((fuelAmount * ONE_UNIT_IN_WEI) < type(uint64).max / 2);
    vm.assume(fuelMaxCapacity > (fuelAmount * fuelUnitVolume));

    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    fuelSystem.configureFuelParameters(
      smartObjectId,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      fuelAmount
    );
    vm.stopPrank();
    FuelData memory fuel = Fuel.get(smartObjectId);
    assertEq(fuelAmount * ONE_UNIT_IN_WEI, fuel.fuelAmount);
  }

  function testSetFuelUnitVolume(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    fuelSystem.setFuelUnitVolume(smartObjectId, fuelUnitVolume);
    vm.stopPrank();

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelUnitVolume, fuel.fuelUnitVolume);
  }

  function testSetFuelConsumptionIntervalInSeconds(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    fuelSystem.setFuelConsumptionIntervalInSeconds(smartObjectId, fuelConsumptionIntervalInSeconds);
    vm.stopPrank();

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelConsumptionIntervalInSeconds, fuel.fuelConsumptionIntervalInSeconds);
  }

  function testSetFuelMaxCapacity(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    fuelSystem.setFuelMaxCapacity(smartObjectId, fuelMaxCapacity);
    vm.stopPrank();

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelMaxCapacity, fuel.fuelMaxCapacity);
  }

  function testDepositFuel(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(fuelAmount > 0 && fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume((fuelAmount * fuelUnitVolume) < fuelMaxCapacity);
    vm.assume(fuelMaxCapacity > (fuelAmount * fuelUnitVolume));
    vm.assume(fuelConsumptionIntervalInSeconds > 60); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    vm.stopPrank();
    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, fuelAmount * ONE_UNIT_IN_WEI);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testDepositFuelTwice(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount > 0 && fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume(fuelAmount * fuelUnitVolume * 2 < fuelMaxCapacity);

    testDepositFuel(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount);
    vm.startPrank(deployer);
    fuelSystem.depositFuel(smartObjectId, fuelAmount);
    vm.stopPrank();

    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, fuelAmount * 2 * ONE_UNIT_IN_WEI);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumption(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount > 0 && fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision

    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    uint256 fuelConsumption = ((timeElapsed * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS)); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount * (10 ** DECIMALS) > fuelConsumption);

    testDepositFuel(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount);
    vm.startPrank(deployer);
    deployableSystem.bringOnline(smartObjectId);

    vm.warp(block.timestamp + timeElapsed);
    fuelSystem.updateFuel(smartObjectId);
    vm.stopPrank();
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
    vm.assume(fuelAmount > 0 && fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume(fuelConsumptionIntervalInSeconds > 3600 && fuelConsumptionIntervalInSeconds < (24 * 3600)); // relatively high consumption
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds

    uint256 fuelConsumption = ((timeElapsed * ONE_UNIT_IN_WEI) / fuelConsumptionIntervalInSeconds) +
      (1 * ONE_UNIT_IN_WEI); // bringing online consumes exactly one wei's worth of gas for tick purposes
    vm.assume(fuelAmount * ONE_UNIT_IN_WEI < fuelConsumption);

    testDepositFuel(fuelUnitVolume, fuelConsumptionIntervalInSeconds, UINT256_MAX, fuelAmount);
    vm.startPrank(deployer);
    deployableSystem.bringOnline(smartObjectId);

    vm.warp(block.timestamp + timeElapsed);
    fuelSystem.updateFuel(smartObjectId);
    vm.stopPrank();

    FuelData memory fuelData = Fuel.get(smartObjectId);

    assertEq(fuelData.fuelAmount, 0);
    assertEq(fuelData.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testFuelRefundDuringGlobalOffline(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelAmount,
    uint256 timeElapsedBeforeOffline,
    uint256 globalOfflineDuration,
    uint256 timeElapsedAfterOffline
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelAmount > 0 && fuelAmount < (type(uint64).max) / 2);
    vm.assume(fuelUnitVolume > 0 && fuelUnitVolume < (type(uint64).max) / 2);
    vm.assume(fuelConsumptionIntervalInSeconds < (type(uint256).max / 1e18) && fuelConsumptionIntervalInSeconds > 1); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsedBeforeOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(timeElapsedAfterOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(globalOfflineDuration < 7 days); // Example constraint: timeElapsed is less than 7 days in seconds
    uint256 fuelConsumption = ((timeElapsedBeforeOffline * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds) +
      (1 * (10 ** DECIMALS));
    fuelConsumption += ((timeElapsedAfterOffline * (10 ** DECIMALS)) / fuelConsumptionIntervalInSeconds);
    vm.assume(fuelAmount * (10 ** DECIMALS) > fuelConsumption); // this time we want to run out of fuel

    testDepositFuel(fuelUnitVolume, fuelConsumptionIntervalInSeconds, UINT256_MAX, fuelAmount);
    vm.startPrank(deployer);
    deployableSystem.bringOnline(smartObjectId);

    vm.warp(block.timestamp + timeElapsedBeforeOffline);
    deployableSystem.globalPause();
    vm.warp(block.timestamp + globalOfflineDuration);
    deployableSystem.globalResume();
    vm.warp(block.timestamp + timeElapsedAfterOffline);

    fuelSystem.updateFuel(smartObjectId);
    vm.stopPrank();

    FuelData memory data = Fuel.get(smartObjectId);

    // Round values to nearest whole number before comparison
    uint256 expectedAmount = ((fuelAmount * (10 ** DECIMALS) - fuelConsumption) / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;
    uint256 actualAmount = (data.fuelAmount / ONE_UNIT_IN_WEI) * ONE_UNIT_IN_WEI;

    assertEq(actualAmount, expectedAmount);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  }
}
