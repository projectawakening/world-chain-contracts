// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";
import { RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes16 constant MODULE_NAME = "access-control";
bytes14 constant MODULE_NAMESPACE = "access-control";
ResourceId constant MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, MODULE_NAMESPACE))
);

bytes16 constant HAS_ROLE_NAME = "HasRole";
bytes16 constant ROLE_ADMIN_NAME = "RoleAdmin";
bytes16 constant ENTITY_TO_ROLE_NAME = "EntityToRole";
bytes16 constant ENTITY_TO_ROLE_AND_NAME = "EntityToRoleAND";
bytes16 constant ENTITY_TO_ROLE_OR_NAME = "EntityToRoleOR";

bytes16 constant ACCESS_CONTROL_SYSTEM_NAME = "AccessControlSys";
