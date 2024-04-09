// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { LOCATION_SYSTEM_NAME, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: name });
  }

  function locationTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: LOCATION_TABLE_NAME });
  }

  function locationSystemId(bytes14 namespace) internal view returns (ResourceId systemId) {
    systemId = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: LOCATION_SYSTEM_NAME });
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace))) {
      // in the way this is used, that would mean we registered this on `FRONTIER_WORLD_DEPLOYMENT_NAMESPACE`
      systemId = WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
        name: LOCATION_SYSTEM_NAME
      });
    }
  }
}
