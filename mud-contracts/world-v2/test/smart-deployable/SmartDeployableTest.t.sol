// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { State, SmartObjectData } from "../../src/systems/smart-deployable/types.sol";

import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { State } from "../../src/codegen/common.sol";
import { GlobalDeployableState, DeployableState, DeployableTokenTable } from "../../src/codegen/index.sol";
import { ISmartDeployableSystem } from "../../src/codegen/world/ISmartDeployableSystem.sol";
import { SmartDeployableSystem } from "../../src/systems/smart-deployable/SmartDeployableSystem.sol";
import { GlobalDeployableStateData } from "../../src/codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { Location, LocationData } from "../../src/codegen/tables/Location.sol";
import { Fuel, FuelData } from "../../src/codegen/tables/Fuel.sol";
import { FuelSystem } from "../../src/systems/fuel/FuelSystem.sol";

import { SmartDeployableUtils } from "../../src/systems/smart-deployable/SmartDeployableUtils.sol";
import { LocationUtils } from "../../src/systems/location/LocationUtils.sol";
import { FuelUtils } from "../../src/systems/fuel/FuelUtils.sol";

contract SmartDeployableTest is MudTest {
  IBaseWorld world;
  SmartDeployableSystem smartDeployable;

  using SmartDeployableUtils for bytes14;

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

  function testRegisterDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity
  ) public {
    vm.assume(entityId != 0);
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionPerMinute != 0);
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
        (entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity)
      )
    );

    DeployableStateData memory tableData = DeployableState.get(entityId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.currentState), uint8(tableData.currentState));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  // test anchor
  function testAnchor(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(entityId != 0);
    testRegisterDeployable(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity);

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.anchor, (entityId, location)));

    ResourceId locationSystemId = LocationUtils.locationSystemId();
    LocationData memory tableData = Location.get(entityId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(entityId)));
  }

  function testBringOnline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, smartObjectData, fuelUnitVolume, fuelConsumptionPerMinute, fuelMaxCapacity, location);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < fuelMaxCapacity);

    ResourceId deployableSystemId = SmartDeployableUtils.smartDeployableSystemId();
    ResourceId fuelSystemId = FuelUtils.fuelSystemId();
    world.call(fuelSystemId, abi.encodeCall(FuelSystem.depositFuel, (entityId, 1)));

    world.call(deployableSystemId, abi.encodeCall(SmartDeployableSystem.bringOnline, (entityId)));
  }

  // test bringoffline
  function testBringOffline(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {}

  // test unanchor
  function testUnanchor(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {}

  // test destroyDeployable
  function testDestroyDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {}
}
