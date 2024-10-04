// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant SMART_TURRET_MODULE_NAME = "SmartTurretModul";
bytes14 constant SMART_TURRET_MODULE_NAMESPACE = "SmartTurretMod";

ResourceId constant SMART_TURRET_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, SMART_TURRET_MODULE_NAMESPACE))
);

bytes16 constant SMART_TURRET_CONFIG_TABLE_NAME = "SmartTurretConfi";
