// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

uint8 constant INVALID_ID = 0;
uint256 constant EMPTY_MODULE_ID = uint256(keccak256("EMPTY_MODULE_ID"));

bytes16 constant SMART_OBJECT_MODULE_NAME = "SmartObjModule";
bytes14 constant SMART_OBJECT_MODULE_NAMESPACE= "SmartObjModule";

ResourceId constant SMART_OBJECT_MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, SMART_OBJECT_MODULE_NAMESPACE))
);


bytes16 constant ENTITY_TYPE_NAME = "EntityType";
bytes16 constant ENTITY_TABLE_NAME = "EntityTable";
bytes16 constant ENTITY_TYPE_ASSOCIATION_NAME = "EntityTypeAssoci";
bytes16 constant ENTITY_MAP_NAME = "EntityMapTable";
bytes16 constant ENTITY_ASSOCIATION_NAME = "EntityAssociatio";
bytes16 constant MODULE_TABLE_NAME = "ModuleTable";
bytes16 constant MODULE_SYSTEM_LOOKUP_NAME = "ModuleSystemLook";
bytes16 constant HOOK_TABLE_NAME = "HookTable";
bytes16 constant HOOK_TARGET_BEFORE_NAME = "HookTargetBefore";
bytes16 constant HOOK_TARGET_AFTER_NAME = "HookTargetAfter";

bytes16 constant ENTITY_CORE_SYSTEM_NAME = "EntityCoreSystem";
bytes16 constant MODULE_CORE_SYSTEM_NAME = "ModuleCoreSystem";
bytes16 constant HOOK_CORE_SYSTEM_NAME = "HookCoreSystem";