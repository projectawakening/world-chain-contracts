// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { Utils as SOFUtils } from "./utils.sol";
import { SMART_OBJECT_MODULE_NAME } from "./constants.sol";

import { SmartObjectLib } from "./SmartObjectLib.sol";
import { OBJECT, CLASS } from "./constants.sol";

library SOFInitializationLibrary {
  using SmartObjectLib for SmartObjectLib.World;
  using SOFUtils for bytes14;

  function init(IBaseWorld world, bytes14 sofNamespace) internal {
        // TODO: decouple this
    // we can just forward this as-is since ModuleCore already handles re-registration errors
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = sofNamespace.entityCoreSystemId();
    systemIds[1] = sofNamespace.moduleCoreSystemId();
    systemIds[2] = sofNamespace.hookCoreSystemId();

    SmartObjectLib.World memory smartObject = SmartObjectLib.World({ namespace: sofNamespace, iface: world });
    smartObject.registerEVEModules(
      uint256(ResourceId.unwrap(WorldResourceIdLib.encode(RESOURCE_SYSTEM, sofNamespace, SMART_OBJECT_MODULE_NAME))), //moduleId
      SMART_OBJECT_MODULE_NAME,
      systemIds
    );
    // setting up basic entity types
    smartObject.registerEntityType(CLASS, "Class");
    smartObject.registerEntityType(OBJECT, "Object");
    smartObject.registerEntityTypeAssociation(OBJECT, CLASS);
  }
}