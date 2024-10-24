//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { DEPLOYMENT_NAMESPACE } from "./../constants.sol";

/**
 * @title Utils to calculate systemId by namespace and system name
 */
library SmartGateUtils {
  function smartGateSystemId() public pure returns (ResourceId systemId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: DEPLOYMENT_NAMESPACE, name: "SmartGateSystem" });
  }
}
