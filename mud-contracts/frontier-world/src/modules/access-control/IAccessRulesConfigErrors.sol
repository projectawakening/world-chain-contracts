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
   * @dev the configuration stored at `configId` is invalid and must be reconfigured
   */
  error AccessRulesConfigInvalidConfig(uint256 configId);
}