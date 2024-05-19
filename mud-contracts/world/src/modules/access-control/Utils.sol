// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: name });
  }

  function accessControlSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: ACCESS_CONTROL_SYSTEM_NAME });
  }

  function accessRulesConfigSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: namespace,
        name: ACCESS_RULES_CONFIG_SYSTEM_NAME
      });
  }

  function roleTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_TABLE_NAME });
  }

  function hasRoleTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: HAS_ROLE_TABLE_NAME });
  }

  function roleAdminChangedTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_ADMIN_CHANGED_TABLE_NAME });
  }

  function roleCreatedTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_CREATED_TABLE_NAME });
  }

  function roleGrantedTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_GRANTED_TABLE_NAME });
  }

  function roleRevokedTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ROLE_REVOKED_TABLE_NAME });
  }

  function accessConfigTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ACCESS_CONFIG_TABLE_NAME });
  }
}
