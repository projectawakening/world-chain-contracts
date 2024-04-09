// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { ENTITY_CORE_SYSTEM_NAME, MODULE_CORE_SYSTEM_NAME, HOOK_CORE_SYSTEM_NAME, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal view returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: _namespace(namespace), name: name });
  }

  function entityCoreSystemId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: _namespace(namespace),
        name: ENTITY_CORE_SYSTEM_NAME
      });
  }

  function moduleCoreSystemId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: _namespace(namespace),
        name: MODULE_CORE_SYSTEM_NAME
      });
  }

  function hookCoreSystemId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: _namespace(namespace),
        name: HOOK_CORE_SYSTEM_NAME
      });
  }

  function entityTypeTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: _namespace(namespace), name: ENTITY_TYPE_NAME });
  }

  function entityTableTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: _namespace(namespace), name: ENTITY_TABLE_NAME });
  }

  function entityTypeAssociationTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: ENTITY_TYPE_ASSOCIATION_NAME
      });
  }

  function entityMapTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: _namespace(namespace), name: ENTITY_MAP_NAME });
  }

  function entityAssociationTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: ENTITY_ASSOCIATION_NAME
      });
  }

  function moduleTableTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: _namespace(namespace), name: MODULE_TABLE_NAME });
  }

  function moduleSystemLookupTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: MODULE_SYSTEM_LOOKUP_NAME
      });
  }

  function hookTableTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: _namespace(namespace), name: HOOK_TABLE_NAME });
  }

  function hookTargetBeforeTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: HOOK_TARGET_BEFORE_NAME
      });
  }

  function hookTargetAfterTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: HOOK_TARGET_AFTER_NAME
      });
  }

  function _namespace(bytes14 namespace) internal view returns (bytes14) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace))) {
      return FRONTIER_WORLD_DEPLOYMENT_NAMESPACE;
    }
    return namespace;
  }
}
