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
import { Location } from "../../src/codegen/index.sol";
import { ILocationSystem } from "../../src/codegen/world/ILocationSystem.sol";
import { LocationSystem } from "../../src/systems/location/LocationSystem.sol";
import { Location } from "../../src/codegen/tables/Location.sol";
import { LocationData } from "../../src/codegen/tables/Location.sol";

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

  function testSaveLocation(uint256 smartObjectId, uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__saveLocation.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.saveLocation, (smartObjectId, solarSystemId, x, y, z)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(solarSystemId, location.solarSystemId);
    assertEq(x, location.x);
    assertEq(y, location.y);
    assertEq(z, location.z);
  }

  function testGetLocation(uint256 smartObjectId, uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__saveLocation.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.saveLocation, (smartObjectId, solarSystemId, x, y, z)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(solarSystemId, location.solarSystemId);
    assertEq(x, location.x);
    assertEq(y, location.y);
    assertEq(z, location.z);
  }

  function testSetSolarSystemId(uint256 smartObjectId, uint256 solarSystemId) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__setSolarSystemId.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.setSolarSystemId, (smartObjectId, solarSystemId)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(solarSystemId, location.solarSystemId);
  }

  function testSetX(uint256 smartObjectId, uint256 x) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__setX.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.setX, (smartObjectId, x)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(x, location.x);
  }

  function testSetY(uint256 smartObjectId, uint256 y) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__setY.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.setY, (smartObjectId, y)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(y, location.y);
  }

  function testSetZ(uint256 smartObjectId, uint256 z) public {
    vm.assume(smartObjectId != 0);
    bytes4 functionSelector = ILocationSystem.eveworld__setZ.selector;

    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);
    world.call(systemId, abi.encodeCall(LocationSystem.setZ, (smartObjectId, z)));

    LocationData memory location = Location.get(smartObjectId);

    assertEq(z, location.z);
  }
}
