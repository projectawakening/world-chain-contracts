// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IWorldWithEntryContext } from "../../src/IWorldWithEntryContext.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { LOCATION_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/location/Utils.sol";
import { LocationLib } from "../../src/modules/location/LocationLib.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

contract LocationTest is MudTest {
  using Utils for bytes14;
  using LocationLib for LocationLib.World;
  using WorldResourceIdInstance for ResourceId;

  IWorldWithEntryContext world;
  LocationLib.World location;

  function setUp() public override {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithEntryContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    location = LocationLib.World(world, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address LocationSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.locationSystemId());
    ResourceId locationSystemId = SystemRegistry.get(LocationSystem);
    assertEq(locationSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testCreateLocation(uint256 entityId, uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(entityId != 0);
    LocationTableData memory locationData = LocationTableData({ solarSystemId: solarSystemId, x: x, y: y, z: z });

    location.saveLocation(entityId, locationData);

    LocationTableData memory tableData = LocationTable.get(entityId);

    assertEq(locationData.solarSystemId, tableData.solarSystemId);
    assertEq(locationData.x, tableData.x);
    assertEq(locationData.y, tableData.y);
    assertEq(locationData.z, tableData.z);
  }
}
