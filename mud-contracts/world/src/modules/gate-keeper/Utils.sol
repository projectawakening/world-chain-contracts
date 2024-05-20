//SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { GATE_KEEPER_TABLE_NAME } from "./constants.sol";

// import { GATE_KEEPER_SYSTEM_NAME } from "@eveworld/common-constants/src/constants.sol";
// clash with a version of npm that doesnt exist yet
bytes16 constant GATE_KEEPER_SYSTEM_NAME = "GateKeeper";


library Utils {
  function gateKeeperTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: GATE_KEEPER_TABLE_NAME });
  }

  function gateKeeperSystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: GATE_KEEPER_SYSTEM_NAME });
  }
}
