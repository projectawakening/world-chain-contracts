// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant SMART_GATE_MODULE_NAME = "SmartGate";
bytes14 constant SMART_GATE_MODULE_NAMESPACE = "SmartGate";

ResourceId constant SMART_GATE_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, SMART_GATE_MODULE_NAMESPACE))
);

bytes16 constant SMART_GATE_CONFIG_TABLE_NAME = "SmartGateConfigT";
bytes16 constant SMART_GATE_LINK_TABLE_NAME = "SmartGateLinkTab";
