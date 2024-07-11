// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { ACCESS_CONTROL_SYSTEM_NAME, ACCESS_ROLE_TABLE_NAME, ACCESS_ENFORCEMENT_TABLE_NAME } from "./constants.sol";

import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function accessRoleTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ACCESS_ROLE_TABLE_NAME });
  }

  function accessEnforcementTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ACCESS_ENFORCEMENT_TABLE_NAME });
  }

  function accessControlSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: ACCESS_CONTROL_SYSTEM_NAME });
  }
}
