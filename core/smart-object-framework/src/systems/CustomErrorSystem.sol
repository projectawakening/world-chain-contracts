// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

contract CustomErrorSystem is System {
  error EntityNotRegistered(uint256 entityId, string message);
  error EntityNotAssociatedWithModule(uint256 entityId, string message);
  error SystemNotAssociatedWithModule(ResourceId tableId, string message);
  error FunctionSelectorNotRegistered(bytes4 functionSelector, string message);

  error InvalidEntityId();
  error EntityAlreadyRegistered(uint256 entityId, string message);
  error EntityTypeMismatch(uint256 entityId, uint256 expectedType, uint256 actualType);
  error NoClassTag(uint256 entityId);
  error ModuleNotFound(string message);

  error HookAlreadyRegistered(uint256 hookId, string message);
  error HookNotRegistered(uint256 hookId, string message);
}
