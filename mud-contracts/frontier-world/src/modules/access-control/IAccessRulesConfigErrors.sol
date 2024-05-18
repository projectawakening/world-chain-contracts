// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev External interface for AccessRulesConfig originating errors.
 */
interface IAccessRulesConfigErrors {
  /**
   * @dev the configId for the access configuration was set to zero, which is prohibited
   */
  error AccessRulesConfigIdOutOfBounds();

  /**
   * @dev the enforcement setting can only be single roles for calling {AccessRulesConfig.setAccessControlRoles
   */
  error AccessRulesConfigEnforcementOutOfBounds();
}