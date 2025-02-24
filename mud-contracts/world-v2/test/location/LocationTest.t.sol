// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";
import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { getKeysWithValue } from "@latticexyz/world-modules/src/modules/keyswithvalue/getKeysWithValue.sol";

import { Location } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { LocationData } from "../../src/namespaces/evefrontier/codegen/tables/Location.sol";
import { LocationSystemLib, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EveTest } from "../EveTest.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { AccessSystem } from "../../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";

contract LocationTest is EveTest {
  uint256 smartObjectId = 1234;

  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(deployer);
    uint256 locationTestClassId = uint256(bytes32("LOCATION_TEST"));
    ResourceId[] memory locationTestSystemIds = new ResourceId[](1);
    locationTestSystemIds[0] = locationSystem.toResourceId();
    entitySystem.registerClass(locationTestClassId, locationTestSystemIds);

    entitySystem.instantiate(locationTestClassId, smartObjectId, deployer);
    vm.stopPrank();
  }

  function testSaveLocation(uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(smartObjectId != 0);

    vm.startPrank(deployer);
    locationSystem.saveLocation(smartObjectId, LocationData({ solarSystemId: solarSystemId, x: x, y: y, z: z }));
    vm.stopPrank();

    LocationData memory location = Location.get(smartObjectId);

    assertEq(solarSystemId, location.solarSystemId);
    assertEq(x, location.x);
    assertEq(y, location.y);
    assertEq(z, location.z);
  }

  function testGetLocation(uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(smartObjectId != 0);

    vm.startPrank(deployer);
    locationSystem.saveLocation(smartObjectId, LocationData({ solarSystemId: solarSystemId, x: x, y: y, z: z }));
    vm.stopPrank();

    LocationData memory location = Location.get(smartObjectId);

    assertEq(solarSystemId, location.solarSystemId);
    assertEq(x, location.x);
    assertEq(y, location.y);
    assertEq(z, location.z);
  }

  function testMustBeAdminToSetLocation(uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(AccessSystem.Access_NotAdmin.selector, alice));
    locationSystem.saveLocation(smartObjectId, LocationData({ solarSystemId: solarSystemId, x: x, y: y, z: z }));
    vm.stopPrank();
  }
}
