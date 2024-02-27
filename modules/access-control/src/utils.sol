// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";

import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { HAS_ROLE_NAME, ROLE_ADMIN_NAME, ENTITY_TO_ROLE_NAME, ENTITY_TO_ROLE_AND_NAME, ENTITY_TO_ROLE_OR_NAME, ACCESS_CONTROL_SYSTEM_NAME } from "./constants.sol";

library Utils {
  function hasRoleTableId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: HAS_ROLE_NAME });
  }

  function roleAdminTableId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_ADMIN_NAME });
  }

  function entityToRoleTableId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ENTITY_TO_ROLE_NAME });
  }

  function entityToRoleANDTableId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ENTITY_TO_ROLE_AND_NAME });
  }

  function entityToRoleORTableId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ENTITY_TO_ROLE_OR_NAME });
  }

  function accessControlSystemId(bytes14 namespace) pure internal returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: ACCESS_CONTROL_SYSTEM_NAME });
  }
}