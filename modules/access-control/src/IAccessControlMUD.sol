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

  /******************
   *  HOOK METHODS  *
   ******************/

  /**
   * @dev Config function for `onlyRoleHook` method
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param role the role we want to assing to it
   */
  function setOnlyRoleConfig(uint256 entityId, bytes32 role) external;

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding an `onlyRole(bytes32 role)` modifier to that method
   * @param args entity targeted by the Access Control hook
   */
  function onlyRoleHook(bytes memory args) external;

  /**
   * @dev Config function for `onlyRoleANDHook` method
   * Note that the only way to update the OnlyRoleAND array is to give an entirely new one; no in-array item updating methods for now
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param roles the role we want to assing to it
   */
  function setOnlyRoleANDConfig(uint256 entityId, bytes32[] calldata roles) external;

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding a `require(hasRole(roles[0]) && hasRole(roles[1]) && ...for role.length...)` to that method
   * @param entityId entity targeted by the Access Control hook
   */
  function onlyRoleANDHook(uint256 entityId) external;

  /**
   * @dev Config function for `onlyRoleANDHook` method
   * Note that the only way to update the OnlyRoleAND array is to give an entirely new one; no in-array item updating methods for now
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param roles the role we want to assing to it
   */
  function setOnlyRoleORConfig(uint256 entityId, bytes32[] calldata roles) external;

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding a `require(hasRole(roles[0]) || hasRole(roles[1]) || ...for role.length...)` to that method
   * @param entityId entity targeted by the Access Control hook
   */
  function onlyRoleORHook(uint256 entityId) external;
}