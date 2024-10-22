// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { State, SmartObjectData } from "../../src/systems/deployable/types.sol";

import { IWorld } from "../../src/codegen/world/IWorld.sol";
import { State } from "../../src/codegen/common.sol";
import { GlobalDeployableState, DeployableState, DeployableToken } from "../../src/codegen/index.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { GlobalDeployableStateData } from "../../src/codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { Location, LocationData } from "../../src/codegen/tables/Location.sol";
import { Fuel, FuelData } from "../../src/codegen/tables/Fuel.sol";
import { FuelSystem } from "../../src/systems/fuel/FuelSystem.sol";
import { DeployableUtils } from "../../src/systems/deployable/DeployableUtils.sol";
import { SmartCharacterUtils } from "../../src/systems/smart-character/SmartCharacterUtils.sol";
import { LocationUtils } from "../../src/systems/location/LocationUtils.sol";
import { DeployableSystem } from "../../src/systems/deployable/DeployableSystem.sol";
import { SmartCharacterSystem } from "../../src/systems/smart-character/SmartCharacterSystem.sol";
import { FuelUtils } from "../../src/systems/fuel/FuelUtils.sol";
import { EntityRecordData, EntityMetadata } from "../../src/systems/entity-record/types.sol";

import { ONE_UNIT_IN_WEI } from "../../src/systems/constants.sol";

contract DeployableTest is MudTest {
  IBaseWorld world;

  string mnemonic = "test test test test test test test test test test test junk";
  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  uint256 alicePK = vm.deriveKey(mnemonic, 2);

  uint256 characterId = 123;
  address alice = vm.addr(alicePK);
  uint256 tribeId = 100;
  SmartObjectData smartObjectData;

  ResourceId characterSystemId = SmartCharacterUtils.smartCharacterSystemId();
  ResourceId deployableSystemId = DeployableUtils.deployableSystemId();
  ResourceId fuelSystemId = FuelUtils.fuelSystemId();

  function setUp() public virtual override {
    super.setUp();
    world = IBaseWorld(worldAddress);

    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    world.call(
      characterSystemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, alice, tribeId, entityRecord, entityRecordMetadata)
      )
    );
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
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));

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
      deployableSystemId,
      abi.encodeCall(
        DeployableSystem.registerDeployable,
        (smartObjectId, smartObjectData, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity)
      )
    );

    DeployableStateData memory tableData = DeployableState.get(smartObjectId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.currentState), uint8(tableData.currentState));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  function testAnchor(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(smartObjectId != 0);
    testRegisterDeployable(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity);

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.anchor, (smartObjectId, location)));

    LocationData memory tableData = Location.get(smartObjectId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testBringOnline(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(smartObjectId != 0);

    testAnchor(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < fuelMaxCapacity);

    world.call(fuelSystemId, abi.encodeCall(FuelSystem.depositFuel, (smartObjectId, 1)));

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOnline, (smartObjectId)));
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testBringOffline(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(smartObjectId != 0);
    testBringOnline(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.bringOffline, (smartObjectId)));
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testUnanchor(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(smartObjectId != 0);
    testAnchor(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.unanchor, (smartObjectId)));

    assertEq(uint8(State.UNANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testDestroyDeployable(
    uint256 smartObjectId,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    vm.assume(smartObjectId != 0);
    testAnchor(smartObjectId, fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.destroyDeployable, (smartObjectId)));

    assertEq(uint8(State.DESTROYED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testCreateAndAnchorDeployable(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    EntityRecordData memory entityRecordData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory locationData
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));

    world.call(deployableSystemId, abi.encodeCall(DeployableSystem.globalResume, ()));
    world.call(
      deployableSystemId,
      abi.encodeCall(
        DeployableSystem.createAndAnchorDeployable,
        (
          smartObjectId,
          smartAssemblyType,
          entityRecordData,
          smartObjectData,
          fuelUnitVolume,
          fuelConsumptionIntervalInSeconds,
          fuelMaxCapacity,
          locationData
        )
      )
    );

    LocationData memory location = Location.get(smartObjectId);

    assertEq(locationData.solarSystemId, location.solarSystemId);
    assertEq(locationData.x, location.x);
    assertEq(locationData.y, location.y);
    assertEq(locationData.z, location.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }
}
