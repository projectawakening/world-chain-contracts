// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../types.sol";

/**
 * @dev Interface definitions for AccessRules.
 */interface IAccessRules {
  /**
   * @dev All of the following accessRule implementations are hook based logic that implement access control
   *   rules enforcement.
   * `accessRule1()` will use the EnforcementLevel and RolesByContext configuration set for `configId = 1` in its
   *   access rule logic, and so forth...
   *
   * In all instances, if the accessing account value is not a member of at least one of the defined roleIds for its
   *   context and that access context is configured to be enforced, then an {AccessRulesUnauthorizedAccount} error
   *   will be thrown.
   */
  function accessControlRule1(bytes data) external;
  function accessControlRule2(bytes data) external;
  function accessControlRule3(bytes data) external;
  function accessControlRule4(bytes data) external;
  function accessControlRule5(bytes data) external;
}