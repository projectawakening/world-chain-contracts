// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { ENTITY_RECORD_SYSTEM_NAME, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal view returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: _namespace(namespace), name: name });
  }

  function entityRecordTableTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: ENTITY_RECORD_TABLE_NAME
      });
  }

  function entityRecordOffchainTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: ENTITY_RECORD_OFFCHAIN_TABLE_NAME
      });
  }

  function entityRecordSystemId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: _namespace(namespace),
        name: ENTITY_RECORD_SYSTEM_NAME
      });
  }

  function _namespace(bytes14 namespace) internal view returns (bytes14) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace))) {
      return FRONTIER_WORLD_DEPLOYMENT_NAMESPACE;
    }
    return namespace;
  }
}
