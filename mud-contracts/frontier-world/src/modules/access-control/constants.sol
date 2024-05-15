// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant ACCESS_CONTROL_NAME = "AccessControl";
bytes14 constant ACCESS_CONTROL_MODULE_NAMESPACE = "eveworld";

ResourceId constant ACCESS_CONTROL_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, ACCESS_CONTROL_MODULE_NAMESPACE))
);

bytes16 constant ACCESS_RULES_CONFIG_SYSTEM_NAME = "AccessRulesConfi";

bytes16 constant ACCESS_RULES_SYSTEM_NAME = "AccessRules";

bytes16 constant ROLE_TABLE_NAME = "Role";
bytes16 constant HAS_ROLE_TABLE_NAME = "HasRole";
bytes16 constant ROLE_ADMIN_CHANGED_TABLE_NAME = "RoleAdminChanged";
bytes16 constant ROLE_CREATED_TABLE_NAME = "RoleCreated";
bytes16 constant ROLE_GRANTED_TABLE_NAME = "RoleGranted";
bytes16 constant ROLE_REVOKED_TABLE_NAME = "RoleRevoked";
bytes16 constant ACCESS_CONFIG_TABLE_NAME = "AccessConfig";