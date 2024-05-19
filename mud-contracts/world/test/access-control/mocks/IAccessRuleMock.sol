// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Interface definitions for AccessRules.
 */
enum EnforcementLevel {
  NULL,
  TRANSIENT,
  ORIGIN,
  TRANSIENT_AND_ORIGIN
}

interface IAccessRuleMock {
  /**
   * @dev The following accessRule implementation is hook based logic that implement access control
   *   rules enforcement.
   * `accessRuleExample()` uses the EnforcementLevel and RolesByContext configuration set for `configId = 1` in its
   *   access rule logic, see {AccessRulesConfig}
   *
   * If the accessing account is not a member of at least one of the defined roleIds for its
   *   context and that access context is configured to be enforced, then an {AccessRulesUnauthorizedAccount} error
   *   will be thrown.
   */
  function accessRule(uint256 entityId) external;
}
