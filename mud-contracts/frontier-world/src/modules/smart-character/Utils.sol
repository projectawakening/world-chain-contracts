// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { CHARACTERS_TABLE_NAME, CHARACTERS_CONSTANTS_TABLE_NAME, SMART_CHARACTER_SYSTEM_NAME } from "./constants.sol";


library Utils {
  function charactersTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: CHARACTERS_TABLE_NAME });
  }

  function charactersConstantsTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: namespace,
        name: CHARACTERS_CONSTANTS_TABLE_NAME
      });
  }

  function smartCharacterSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: SMART_CHARACTER_SYSTEM_NAME });
  }
}
