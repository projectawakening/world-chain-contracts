// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { STATIC_DATA_SYSTEM_NAME } from "@eve/common-constants/src/constants.sol";

import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: name });
  }

  function staticDataTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: STATIC_DATA_TABLE_NAME });
  }

  function staticDataGlobalTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: STATIC_DATA_GLOBAL_TABLE_NAME });
  }

  function staticDataSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: STATIC_DATA_SYSTEM_NAME });
  }
}
