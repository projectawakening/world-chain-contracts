// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant GATE_KEEPER_MODULE_NAME = "GateKeeper";
bytes14 constant GATE_KEEPER_MODULE_NAMESPACE = "GateKeeper";

bytes16 constant GATE_KEEPER_TABLE_NAME = "GateKeeperTable";