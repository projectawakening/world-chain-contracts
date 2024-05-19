// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RootRoleData } from "../types.sol";

/**
 * @dev Interface definitions for AccessControl.
 */
interface IAccessControl {
  /**
   * @dev Creates a root role which corresponds to a single account which thereafter can be used to create other
   *   root linked roles.
   *
   *   Emits a {RoleCreated} offchain table event.
   *   Emits a {RoleAdminChanged} offchain table event.
   *   Emits a {RoleGranted} offchain table event.
   */
  function createRootRole(address callerConfirmation) external returns (RootRoleData memory);

  /**
   * @dev Creates a new role with `name` linked to `adminId`'s rootId value and with `adminId` as the assigned admin
   *   role. Returns the new created role's `roleId`.
   *
   *   Emits a {RoleCreated} offchain table event.
   *   Emits a {RoleAdminChanged} offchain table event.
   *
   * Requirements:
   *
   *   - `world().initialMsgSender` must be a member of `adminId`
   *   _ `rootAcctConfirmation` must match the root value` of `adminId`
   */
  function createRole(string calldata name, address rootAcctConfirmation, bytes32 adminId) external returns (bytes32);

  /**
   * @dev Sets a new admin role for a role with given `roleId`.
   *
   *   Emits a {RoleAdminChanged} offchain table event.
   *
   * Requirements:
   *   - `world().initialMsgSender` must be a member of the current admin role
   *   _ `newAdminId` must not be the roleId of the current admin role
   */
  function transferRoleAdmin(bytes32 roleId, bytes32 newAdminId) external;

  /**
   * @dev Grants `roleId` role memership to `account`.
   *
   * If `account` had not been already granted `roleId` membership, emits a {RoleGranted}
   * offchain table event.
   *
   * Requirements:
   *
   * - `world().initialMsgSender` must be a member of `roleId`'s admin role.
   */
  function grantRole(bytes32 roleId, address account) external;

  /**
   * @dev Revokes `roleId` membership for `account`.
   *
   * If `account` had been granted `roleId`, emits a {RoleRevoked} offchain table event.
   *
   * Requirements:
   *
   * - `world().initialMsgSender` must be a member of `roleId`'s admin role.
   */
  function revokeRole(bytes32 roleId, address account) external;

  /**
   * @dev Revokes `roleId` from `world().initialMsgSender`.
   *
   * Roles are often managed via {grantRole} and {revokeRole}: this function's
   * purpose is to provide a mechanism for accounts to lose their privileges
   * if they are compromised (such as when a trusted device is misplaced) or to decentralize administration
   * of a contract's logic.
   *
   * If the calling account had been granted `roleId`, emits a {RoleRevoked} offchain table event.
   *
   * Requirements:
   *
   * - `world().initialMsgSender` must be `callerConfirmation`.
   */
  function renounceRole(bytes32 roleId, address callerConfirmation) external;

  /**
   * @dev Returns `true` if `account` has been granted `roleId`.
   */
  function hasRole(bytes32 roleId, address account) external view returns (bool);

  /**
   * @dev Returns the `adminId` of the admin role that manages `roleId`.
   */
  function getRoleAdmin(bytes32 roleId) external view returns (bytes32);

  /**
   * @dev Returns a `roleId` given a `rootAcct` and a `name`.
   */
  function getRoleId(address rootAcct, string calldata name) external view returns (bytes32);

  /**
   * @dev Returns `true` if `roleId` has been created
   */
  function roleExists(bytes32 roleId) external view returns (bool);

  /**
   * @dev Returns `true` if `roleId` has been created and is a root role
   */
  function isRootRole(bytes32 roleId) external view returns (bool);
}
