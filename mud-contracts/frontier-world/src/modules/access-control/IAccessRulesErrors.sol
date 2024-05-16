// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EnforcementLevel } from "./types.sol";

/**
 * @dev External interface for AccessRules originating errors.
 */
interface IAccessRulesErrors {
  struct AccessReport {
    address account;
    bytes32[] roleIds;
  }

  /**
   * @dev `account` is NOT a member of any the listed required `roleIds`
   */
  error AccessRulesUnauthorizedAccount(
    EnforcementLevel enforcementLevel,
    AccessReport transient,
    AccessReport mud,
    AccessReport origin
  );
}