// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { SMART_DEPLOYABLE_SYSTEM_NAME } from "@eve/common-constants/src/constants.sol";

import { GLOBAL_STATE_TABLE_NAME, DEPLOYABLE_STATE_TABLE_NAME } from "./constants.sol";

library Utils {
  function globalStateTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: namespace,
        name: GLOBAL_STATE_TABLE_NAME
      });
  }

  function deployableStateTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: namespace,
        name: DEPLOYABLE_STATE_TABLE_NAME
      });
  }

  function smartDeployableSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: namespace,
        name: SMART_DEPLOYABLE_SYSTEM_NAME
      });
  }
}
