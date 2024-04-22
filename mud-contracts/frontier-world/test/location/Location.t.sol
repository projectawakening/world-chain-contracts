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
import { EntityCore } from "@eve/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eve/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eve/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";

import { LOCATION_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { Utils } from "../../src/modules/location/Utils.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { LocationLib } from "../../src/modules/location/LocationLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

contract LocationTest is Test {
  using Utils for bytes14;
  using LocationLib for LocationLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  LocationLib.World location;
  LocationModule locationModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    baseWorld.installModule(new SmartObjectFrameworkModule(), abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore()));
    baseWorld.installModule(new LocationModule(), abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    location = LocationLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
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

    LocationTableData memory tableData = LocationTable.get(DEPLOYMENT_NAMESPACE.locationTableId(), entityId);

    assertEq(locationData.solarSystemId, tableData.solarSystemId);
    assertEq(locationData.x, tableData.x);
    assertEq(locationData.y, tableData.y);
    assertEq(locationData.z, tableData.z);
  }
}
