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

contract StaticDataTest is MudTest {
  IBaseWorld world;

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
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelBalance.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(
        FuelSystem.setFuelBalance,
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
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelBalance.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(
        FuelSystem.setFuelBalance,
        (smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, fuelAmount, lastUpdatedAt)
      )
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  function testSetFuelUnitVolume(uint256 smartObjectId, uint256 fuelUnitVolume) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelUnitVolume.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelUnitVolume, (smartObjectId, fuelUnitVolume)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelUnitVolume, fuel.fuelUnitVolume);
  }

  function testSetFuelConsumptionIntervalInSeconds(
    uint256 smartObjectId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelConsumptionIntervalInSeconds.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(
      systemId,
      abi.encodeCall(FuelSystem.setFuelConsumptionIntervalInSeconds, (smartObjectId, fuelConsumptionIntervalInSeconds))
    );

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelConsumptionIntervalInSeconds, fuel.fuelConsumptionIntervalInSeconds);
  }

  function testSetFuelMaxCapacity(uint256 smartObjectId, uint256 fuelMaxCapacity) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelMaxCapacity.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelMaxCapacity, (smartObjectId, fuelMaxCapacity)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelMaxCapacity, fuel.fuelMaxCapacity);
  }

  function testSetFuelAmount(uint256 smartObjectId, uint256 fuelAmount) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__setFuelAmount.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.setFuelAmount, (smartObjectId, fuelAmount)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  function testSetLastUpdatedAt(uint256 smartObjectId, uint256 lastUpdatedAt) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__setLastUpdatedAt.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.setLastUpdatedAt, (smartObjectId, lastUpdatedAt)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(lastUpdatedAt, fuel.lastUpdatedAt);
  }

  // test deposit fuel
  function testDepositFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__depositFuel.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.depositFuel, (smartObjectId, fuelAmount)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }

  // test withdraw fuel
  function testWithdrawFuel(uint256 smartObjectId, uint256 fuelAmount) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = IFuelSystem.eveworld__withdrawFuel.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(FuelSystem.withdrawFuel, (smartObjectId, fuelAmount)));

    FuelData memory fuel = Fuel.get(smartObjectId);

    assertEq(fuelAmount, fuel.fuelAmount);
  }
}
