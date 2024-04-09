// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { SMART_CHARACTER_SYSTEM_NAME, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { CHARACTERS_TABLE_NAME, CHARACTERS_CONSTANTS_TABLE_NAME } from "./constants.sol";

library Utils {
  function charactersTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: CHARACTERS_TABLE_NAME
      });
  }

  function charactersConstantsTableId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: _namespace(namespace),
        name: CHARACTERS_CONSTANTS_TABLE_NAME
      });
  }

  function smartCharacterSystemId(bytes14 namespace) internal view returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: _namespace(namespace),
        name: SMART_CHARACTER_SYSTEM_NAME
      });
  }

  function _namespace(bytes14 namespace) internal view returns (bytes14) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(namespace))) {
      return FRONTIER_WORLD_DEPLOYMENT_NAMESPACE;
    }
    return namespace;
  }
}
