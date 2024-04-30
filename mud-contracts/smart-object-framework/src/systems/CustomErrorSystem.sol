// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

contract CustomErrorSystem is System {
  error InvalidEntityId();
  error EntityTypeNotRegistered(uint8 entityId, string message);
  error EntityNotRegistered(uint256 entityId, string message);
  error EntityTypeAlreadyRegistered(uint8 entityId, string message);
  error EntityAlreadyRegistered(uint256 entityId, string message);
  error EntityTypeAssociationNotAllowed(uint8 entityType, uint8 taggedEntityType, string message);
  error EntityNotAssociatedWithModule(uint256 entityId, string message);
  error EntityAlreadyAssociated(uint256 entityId, uint256 associatedId, string message);
  error EntityAlreadyTagged(uint256 entityId, uint256 tagId, string message);

  error ResourceNotRegistered(ResourceId resourceId, string message);
  error SystemNotAssociatedWithModule(ResourceId tableId, string message);
  error FunctionSelectorNotRegistered(bytes4 functionSelector, string message);

  error ModuleNotFound(string message);
  error ModuleNotRegistered(uint256 moduleId, string message);
  error InvalidModuleId(uint256 moduleId, string message);
  error SystemAlreadyAssociatedWithModule(uint256 moduleId, ResourceId systemId, string message);

  error HookAlreadyRegistered(uint256 hookId, string message);
  error HookNotRegistered(uint256 hookId, string message);

  error InvalidArrayLength(uint256 length1, uint256 length2, string message);
}
