// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EnforcementLevel } from "./IAccessRuleMock.sol";

/**
 * @dev External interface for AccessRuleMock originating errors.
 */
interface IAccessRuleMockErrors {
  struct AccessReport {
    address account;
    bytes32[] roleIds;
  }

  /**
   * @dev `account` is NOT a member of any the listed required `roleIds`
   */
  error AccessRulesUnauthorizedAccount(EnforcementLevel enforcementLevel, AccessReport transient, AccessReport origin);
}
