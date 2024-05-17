// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RolesByContext, EnforcementLevel } from "../types.sol";

/**
 * @dev Interface definitions for AccessRulesConfig
 */
interface IAccessRulesConfig {

  /**
   * @dev Sets a configuration of access control `roleIds` for each access context and assign these `roleIds` to an
   *   `entityId` and `configId` configuration. See {AccessControl} for more info on `roleIds`
   *
   * Implements the  `hookable()` modifier, see {EveSystem} and {HookCore} for more details.
   *
   * Throws the error {AccessRulesConfigIdOutOfBounds} if `configId` is 0.
   */
  function setAccessControlRoles(uint256 entityId, uint256 configId, RolesByContext memory rolesByContext) external;

  /**
   * @dev Sets an enforcement level for a `configId`, defining which access contexts shoud be enforced for executions
   *   related to `entityId` when this config is used.
   *
   * Implements the  `hookable()` modifier, see {EveSystem} and {HookCore} for more details.
   *
   * Throws the error {AccessRulesConfigIdOutOfBounds} if `configId` is 0.
   */
  function setEnforcementLevel(uint256 entityId, uint256 configId, EnforcementLevel enforcementLevel) external;
}