// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.21;

import { IAccessControl } from "./IAccessControl.sol";

/**
 * @dev External interface extension of AccessControl with new methods to set Role Admins in a safeish way
 * TODO: we need to find a safer way (?)
 */
interface IAccessControlMUD is IAccessControl {
  /**
   * @dev 'account' has already created this Singleton Role
   */
  error AccessControlSingletonRoleExists(address account);

  /**
   * @dev 'role' already exists and has 'roleAdmin' as its admin
   * (tx sent by 'account')
   */
  error AccessControlRoleAlreadyCreated(bytes32 role, address account);

  /**
   * @dev 'role' hook ruleset is uninitialized, needs to be set to something
   */
  error AccessControlHookUnititialized(uint256 entityId);

  /**
   * @dev 'roleAND' hook ruleset is uninitialized, needs to contain at least one member for hook to work
   */
  error AccessControlHookANDUnititialized(uint256 entityId);

  /**
   * @dev 'roleOR' hook ruleset is uninitialized, needs to contain at least one member for hook to work
   */
  error AccessControlHookORUnititialized(uint256 entityId);

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) external returns(bool);

  /**
   * @dev not in the AccessControl specs, specific function to claim a singletonRole
   * Allows us to bootstrap RBAC to a certain address
   * Creates a role ( == bytes32(_msgSender()) ) and assign itself as its own role admin
   */
  function claimSingletonRole(address callerConfirmation) external;

  /**
   * @dev create a new role (role needs to be unused)
   * @param role the role we want to create
   * @param roleAdmin the role admin we want to assign to it (msgSender needs to have it)
   *
   * throws an error {AccessControlRoleAlreadyCreated} if 'role' already exists (e.g. has an admin already)
   * throws an error {AccessControlUnauthorizedAccount} if _msgSender isn't 'roleAdmin'
   */
  function createRole(bytes32 role, bytes32 roleAdmin) external;
}