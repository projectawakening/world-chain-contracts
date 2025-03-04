// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

import { State, SmartObjectData } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";
import { State } from "../../src/codegen/common.sol";
import { GlobalDeployableState, DeployableState, DeployableToken } from "../../src/namespaces/evefrontier/codegen/index.sol";
import { SmartCharacterSystem } from "../../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { GlobalDeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../src/namespaces/evefrontier/codegen/tables/DeployableState.sol";
import { Location, LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { Fuel, FuelData } from "../../src/namespaces/evefrontier/codegen/tables/Fuel.sol";
import { DeployableSystemLib, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartCharacterSystemLib, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { FuelSystemLib, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { EntityRecordData, EntityMetadata } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorDeployableParams } from "../../src/namespaces/evefrontier/systems/deployable/types.sol";

import { ONE_UNIT_IN_WEI } from "../../src/namespaces/evefrontier/systems/constants.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";

contract DeployableTest is MudTest {
  uint256 smartObjectId = 999;
  uint256 characterId = 123;
  uint256 testClassId = uint256(bytes32("TEST"));
  uint256 itemId = 234;
  uint256 tribeId = 100;
  SmartObjectData smartObjectData;

  string mnemonic = "test test test test test test test test test test test junk";
  address deployer = vm.addr(vm.deriveKey(mnemonic, 0));
  address alice = vm.addr(vm.deriveKey(mnemonic, 2));
  address bob = vm.addr(vm.deriveKey(mnemonic, 3));

  function setUp() public virtual override {
    super.setUp();

    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: itemId, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartObjectData = SmartObjectData({ owner: alice, tokenURI: "test" });

    vm.startPrank(deployer);

    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = smartCharacterSystem.toResourceId();
    systemIds[1] = entityRecordSystem.toResourceId();
    systemIds[2] = deployableSystem.toResourceId();
    systemIds[3] = fuelSystem.toResourceId();
    systemIds[4] = locationSystem.toResourceId();
    systemIds[5] = smartAssemblySystem.toResourceId();
    entitySystem.registerClass(testClassId, systemIds);

    smartCharacterSystem.createCharacter(characterId, alice, tribeId, entityRecord, entityRecordMetadata);

    vm.stopPrank();
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
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);

    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, smartObjectData.owner);
    deployableSystem.globalResume();

    DeployableStateData memory data = DeployableStateData({
      createdAt: block.timestamp,
      previousState: State.NULL,
      currentState: State.UNANCHORED,
      isValid: true,
      anchoredAt: block.timestamp,
      updatedBlockNumber: block.number,
      updatedBlockTime: block.timestamp
    });

    deployableSystem.registerDeployable(
      smartObjectId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );

    vm.stopPrank();

    DeployableStateData memory tableData = DeployableState.get(smartObjectId);

    assertEq(data.createdAt, tableData.createdAt);
    assertEq(uint8(data.currentState), uint8(tableData.currentState));
    assertEq(data.updatedBlockNumber, tableData.updatedBlockNumber);
  }

  function testAnchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    testRegisterDeployable(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity);

    vm.startPrank(deployer);
    deployableSystem.anchor(smartObjectId, location);
    vm.stopPrank();

    LocationData memory tableData = Location.get(smartObjectId);

    assertEq(location.solarSystemId, tableData.solarSystemId);
    assertEq(location.x, tableData.x);
    assertEq(location.y, tableData.y);
    assertEq(location.z, tableData.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testBringOnline(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.assume(fuelUnitVolume < type(uint64).max / 2);
    vm.assume(fuelUnitVolume < fuelMaxCapacity);

    vm.startPrank(deployer);
    fuelSystem.depositFuel(smartObjectId, 1);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();
    assertEq(uint8(State.ONLINE), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testBringOffline(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    testBringOnline(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    deployableSystem.bringOffline(smartObjectId);
    vm.stopPrank();
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testUnanchor(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    deployableSystem.unanchor(smartObjectId);
    vm.stopPrank();
    assertEq(uint8(State.UNANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testDestroyDeployable(
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory location
  ) public {
    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);
    vm.startPrank(deployer);
    deployableSystem.destroyDeployable(smartObjectId);
    vm.stopPrank();
    assertEq(uint8(State.DESTROYED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testCreateAndAnchorDeployable(
    string memory smartAssemblyType,
    EntityRecordData memory entityRecordData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory locationData
  ) public {
    vm.assume(fuelUnitVolume != 0);
    vm.assume(fuelConsumptionIntervalInSeconds >= 1);
    vm.assume(fuelMaxCapacity != 0);
    vm.assume((keccak256(abi.encodePacked(smartAssemblyType)) != keccak256(abi.encodePacked(""))));

    vm.startPrank(deployer);
    entitySystem.instantiate(testClassId, smartObjectId, smartObjectData.owner);

    deployableSystem.globalResume();
    deployableSystem.createAndAnchorDeployable(
      CreateAndAnchorDeployableParams({
        smartObjectId: smartObjectId,
        smartAssemblyType: smartAssemblyType,
        entityRecordData: entityRecordData,
        smartObjectData: smartObjectData,
        fuelUnitVolume: fuelUnitVolume,
        fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacity,
        locationData: locationData
      })
    );

    vm.stopPrank();

    LocationData memory location = Location.get(smartObjectId);

    assertEq(locationData.solarSystemId, location.solarSystemId);
    assertEq(locationData.x, location.x);
    assertEq(locationData.y, location.y);
    assertEq(locationData.z, location.z);
    assertEq(uint8(State.ANCHORED), uint8(DeployableState.getCurrentState(smartObjectId)));
  }

  function testOnlineOfflineAccess(uint256 fuelConsumptionIntervalInSeconds, LocationData memory location) public {
    uint256 fuelUnitVolume = 1;
    uint256 fuelMaxCapacity = 100;

    testAnchor(fuelUnitVolume, fuelConsumptionIntervalInSeconds, fuelMaxCapacity, location);

    vm.startPrank(deployer);
    fuelSystem.depositFuel(smartObjectId, fuelMaxCapacity);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    vm.startPrank(alice);
    deployableSystem.bringOffline(smartObjectId);
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();

    vm.startPrank(deployer);
    deployableSystem.bringOffline(smartObjectId);
    vm.stopPrank();

    // just some random dude
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotAdminOrOwner.selector, bob, smartObjectId));
    deployableSystem.bringOnline(smartObjectId);
    vm.stopPrank();
  }
}
