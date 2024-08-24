// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";

import { DEPLOYMENT_NAMESPACE } from "./../constants.sol";
import { SMART_DEPLOYABLE_SYSTEM_NAME } from "@eveworld/common-constants/src/constants.sol";

library SmartDeployableUtils {
  function smartDeployableSystemId() public pure returns (ResourceId systemId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: DEPLOYMENT_NAMESPACE, name: "SmartDeployableS" });
  }
}
