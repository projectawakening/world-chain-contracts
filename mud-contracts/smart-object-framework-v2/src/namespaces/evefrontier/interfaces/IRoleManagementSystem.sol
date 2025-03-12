// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IRoleManagementSystem
 * @dev An interface for the Role Management System functionality
 */
interface IRoleManagementSystem {
  function createRole(bytes32 role, bytes32 admin) external;
  function transferRoleAdmin(bytes32 role, bytes32 newAdmin) external;
  function grantRole(bytes32 role, address account) external;
  function revokeRole(bytes32 role, address account) external;
  function renounceRole(bytes32 role, address callerConfirmation) external;
  function revokeAll(bytes32 role) external;

  function scopedCreateRole(uint256 entityId, bytes32 role, bytes32 admin, address roleMember) external;
  function scopedTransferRoleAdmin(uint256 entityId, bytes32 role, bytes32 newAdmin) external;
  function scopedGrantRole(uint256 entityId, bytes32 role, address account) external;
  function scopedRevokeRole(uint256 entityId, bytes32 role, address account) external;
  function scopedRenounceRole(uint256 entityId, bytes32 role, address callerConfirmation) external;
  function scopedRevokeAll(uint256 entityId, bytes32 role) external;

  error RoleManagement_InvalidRole();
  error RoleManagement_InvalidRoleMember();
  error RoleManagement_RoleAlreadyCreated(bytes32 role);
  error RoleManagement_UnauthorizedAccount(bytes32 role, address caller);
  error RoleManagement_MustRenounceSelf();
  error RoleManagement_BadConfirmation();
  error RoleManagement_RoleDoesNotExist(bytes32 role);
  error RoleManagement_AdminAlreadyAssigned(bytes32 role, bytes32 admin);
}
