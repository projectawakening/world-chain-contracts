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
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import { LOCATION_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/smart-object-framework/src/systems/core/ModuleCore.sol";

import { ModulesInitializationLibrary } from "../../src/utils/ModulesInitializationLibrary.sol";
import { SOFInitializationLibrary } from "@eveworld/smart-object-framework/src/SOFInitializationLibrary.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { CLASS, OBJECT } from "@eveworld/smart-object-framework/src/constants.sol";

import { Utils } from "../../src/modules/location/Utils.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { LocationLib } from "../../src/modules/location/LocationLib.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { LocationTable, LocationTableData } from "../../src/codegen/tables/LocationTable.sol";

contract LocationTest is Test {
  using Utils for bytes14;
  using LocationLib for LocationLib.World;
  using SmartObjectLib for SmartObjectLib.World;
  using ModulesInitializationLibrary for IBaseWorld;
  using SOFInitializationLibrary for IBaseWorld;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  LocationLib.World location;
  SmartObjectLib.World smartObject;

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF module (dependancy)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );
    world.initSOF();

    _installModule(new LocationModule(), DEPLOYMENT_NAMESPACE);
    world.initLocation();

    location = LocationLib.World(world, DEPLOYMENT_NAMESPACE);
    smartObject = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address LocationSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.locationSystemId());
    ResourceId locationSystemId = SystemRegistry.get(LocationSystem);
    assertEq(locationSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testCreateLocation(uint256 entityId, uint256 solarSystemId, uint256 x, uint256 y, uint256 z) public {
    vm.assume(entityId != 0);
    LocationTableData memory locationData = LocationTableData({ solarSystemId: solarSystemId, x: x, y: y, z: z });

    // SOF entity registration
    smartObject.registerEntity(entityId, OBJECT);
    world.associateLocation(entityId);

    location.saveLocation(entityId, locationData);

    LocationTableData memory tableData = LocationTable.get(DEPLOYMENT_NAMESPACE.locationTableId(), entityId);

    assertEq(locationData.solarSystemId, tableData.solarSystemId);
    assertEq(locationData.x, tableData.x);
    assertEq(locationData.y, tableData.y);
    assertEq(locationData.z, tableData.z);
  }
}
