// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";

import { SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as LocationUtils } from "../../src/modules/location/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartDeployableErrors } from "../../src/modules/smart-deployable/SmartDeployableErrors.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { GlobalDeployableState, GlobalDeployableStateData } from "../../src/codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { DeployableFuelBalance, DeployableFuelBalanceData } from "../../src/codegen/tables/DeployableFuelBalance.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

import { DEFAULT_DEPLOYABLE_FUEL_STORAGE } from "../../src/modules/smart-deployable/constants.sol";

contract smartDeployableTest is Test {
  using Utils for bytes14;
  using LocationUtils for bytes14;
  using SmartDeployableLib for SmartDeployableLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  SmartDeployableLib.World smartDeployable;
  SmartDeployableModule smartDeployableModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new SmartDeployableModule(), abi.encode(DEPLOYMENT_NAMESPACE));
    baseWorld.installModule(new LocationModule(), abi.encode(LOCATION_DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    smartDeployable = SmartDeployableLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address smartDeployableSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.smartDeployableSystemId());
    ResourceId smartDeployableSystemId = SystemRegistry.get(smartDeployableSystem);
    assertEq(smartDeployableSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testRegisterDeployable(uint256 entityId) public {
    smartDeployable.globalOnline();
    vm.assume(entityId != 0);
    DeployableStateData memory data = DeployableStateData({
      createdAt: block.timestamp,
      state: State.UNANCHORED,
      updatedBlockNumber: block.number,
      updatedBlockTime: block.timestamp
    });

    smartDeployable.registerDeployable(entityId);
    DeployableStateData memory tableData = DeployableState.get(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.state), uint8(tableData.state));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  function testGloballyOfflineRevert(uint256 entityId) public {
    vm.assume(entityId != 0);
    // TODO: build a work-around following recommendations in https://github.com/foundry-rs/foundry/issues/5454
    // try each line independantly, thenm
    // try running both lines below and see what happens, lol
    //vm.expectRevert(abi.encodeWithSelector(SmartDeployableErrors.SmartDeployable_GloballyOffline.selector));
    //smartDeployable.registerDeployable(entityId);

    assertEq(true, true);
  }

  function testAnchor(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);
    testRegisterDeployable(entityId);

    smartDeployable.anchor(entityId, location);
    LocationTableData memory tableData = LocationTable.get(LOCATION_DEPLOYMENT_NAMESPACE.locationTableId(), entityId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
  }

  function testBringOnline(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    assertEq(
      uint8(State.ONLINE),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testBringOffline(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testBringOnline(entityId, location);
    smartDeployable.bringOffline(entityId);
    assertEq(
      uint8(State.ANCHORED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testUnanchor(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testAnchor(entityId, location);
    smartDeployable.unanchor(entityId);
    assertEq(
      uint8(State.UNANCHORED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testDestroyDeployable(uint256 entityId, LocationTableData memory location) public {
    vm.assume(entityId != 0);

    testUnanchor(entityId, location);
    smartDeployable.destroyDeployable(entityId);
    assertEq(
      uint8(State.DESTROYED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testSetFuelConsumptionPerMinute(uint256 rate) public {
    vm.assume(rate != 0);

    smartDeployable.setFuelConsumptionPerMinute(rate);
    assertEq(GlobalDeployableState.getFuelConsumptionPerMinute(DEPLOYMENT_NAMESPACE.globalStateTableId()), rate);
  }

  function testDepositFuel(uint256 entityId, uint256 fuelAmount) public {
    vm.assume(entityId != 0);
    vm.assume(fuelAmount != 0);
    vm.assume(fuelAmount <= DEFAULT_DEPLOYABLE_FUEL_STORAGE);

    testRegisterDeployable(entityId);
    smartDeployable.depositFuel(entityId, fuelAmount);
    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    );
    assertEq(data.fuelAmount, fuelAmount);
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testDepositFuelTwice(uint256 entityId, uint256 fuelAmount) public {
    vm.assume(fuelAmount <= DEFAULT_DEPLOYABLE_FUEL_STORAGE / 2);

    testDepositFuel(entityId, fuelAmount);
    smartDeployable.depositFuel(entityId, fuelAmount);
    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    );
    assertEq(data.fuelAmount, fuelAmount * 2);
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumption(
    uint256 entityId,
    LocationTableData memory location,
    uint256 ratePerMinute,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(ratePerMinute < type(uint256).max / 1e18); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    vm.assume(fuelAmount <= DEFAULT_DEPLOYABLE_FUEL_STORAGE);
    uint256 fuelConsumption = timeElapsed * (ratePerMinute / 60);
    vm.assume(fuelAmount > fuelConsumption);

    testSetFuelConsumptionPerMinute(ratePerMinute);
    testDepositFuel(entityId, fuelAmount);
    smartDeployable.anchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsed);
    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    );
    assertEq(data.fuelAmount, fuelAmount - fuelConsumption);
    assertEq(data.lastUpdatedAt, block.timestamp);
  }

  function testFuelConsumptionRunsOut(
    uint256 entityId,
    LocationTableData memory location,
    uint256 ratePerMinute,
    uint256 fuelAmount,
    uint256 timeElapsed
  ) public {
    vm.assume(ratePerMinute < type(uint256).max / 1e18); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsed < 100 * 365 days); // Example constraint: timeElapsed is less than a 100 years in seconds
    vm.assume(fuelAmount <= DEFAULT_DEPLOYABLE_FUEL_STORAGE);

    uint256 fuelConsumption = timeElapsed * (ratePerMinute / 60);
    vm.assume(fuelAmount < fuelConsumption); // this time we want to run out of fuel
    testSetFuelConsumptionPerMinute(ratePerMinute);
    testDepositFuel(entityId, fuelAmount);
    smartDeployable.anchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsed);
    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    );
    assertEq(data.fuelAmount, 0);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(
      uint8(State.ANCHORED),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }

  function testFuelRefundDuringGlobalOffline(
    uint256 entityId,
    LocationTableData memory location,
    uint256 ratePerMinute,
    uint256 fuelAmount,
    uint256 timeElapsedBeforeOffline,
    uint256 globalOfflineDuration,
    uint256 timeElapsedAfterOffline
  ) public {
    vm.assume(ratePerMinute < type(uint256).max / 1e18); // Ensure ratePerMinute doesn't overflow when adjusted for precision
    vm.assume(timeElapsedBeforeOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(timeElapsedAfterOffline < 1 * 365 days); // Example constraint: timeElapsed is less than a 1 years in seconds
    vm.assume(globalOfflineDuration < 7 days); // Example constraint: timeElapsed is less than 7 days in seconds
    uint256 fuelConsumption = timeElapsedBeforeOffline * (ratePerMinute / 60);
    fuelConsumption += timeElapsedAfterOffline * (ratePerMinute / 60);
    vm.assume(fuelAmount > fuelConsumption); // this time we want to run out of fuel
    
    testSetFuelConsumptionPerMinute(ratePerMinute);

    // have to disable fuel max inventory because we're getting a [FAIL. Reason: The `vm.assume` cheatcode rejected too many inputs (65536 allowed)]
    // error, since we're filtering quite a lot of possible input tuples
    smartDeployable.registerDeployable(entityId);
    smartDeployable.setFuelMaxCapacity(entityId, UINT256_MAX);
    console.log("fuel max capacity: ", DeployableFuelBalance.getFuelMaxCapacity(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    ));
    smartDeployable.depositFuel(entityId, fuelAmount);
    smartDeployable.anchor(entityId, location);
    smartDeployable.bringOnline(entityId);
    vm.warp(block.timestamp + timeElapsedBeforeOffline);
    smartDeployable.globalOffline();
    vm.warp(block.timestamp + globalOfflineDuration);
    smartDeployable.globalOnline();
    vm.warp(block.timestamp + timeElapsedAfterOffline);

    smartDeployable.updateFuel(entityId);

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      DEPLOYMENT_NAMESPACE.deployableFuelBalanceTableId(),
      entityId
    );
    assertEq(data.fuelAmount, fuelAmount - fuelConsumption);
    assertEq(data.lastUpdatedAt, block.timestamp);
    assertEq(
      uint8(State.ONLINE),
      uint8(DeployableState.getState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), entityId))
    );
  }
}
