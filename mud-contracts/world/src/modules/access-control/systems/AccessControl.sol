/// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { Role, RoleData } from "../../../codegen/tables/Role.sol";
import { HasRole } from "../../../codegen/tables/HasRole.sol";
import { RoleAdminChanged } from "../../../codegen/tables/RoleAdminChanged.sol";
import { RoleCreated } from "../../../codegen/tables/RoleCreated.sol";
import { RoleGranted } from "../../../codegen/tables/RoleGranted.sol";
import { RoleRevoked } from "../../../codegen/tables/RoleRevoked.sol";
import { RootRoleData } from "../types.sol";
import { IAccessControl } from "../interfaces/IAccessControl.sol";
import { IAccessControlErrors } from "../IAccessControlErrors.sol";
import { Utils } from "../Utils.sol";
import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";

/**
 * @title Access Control base contract
 * @author The CCP Games Development Team
 * @notice A contract used for creating and managing groups of roles linked to a root role (and the account membership
 *   of those roles). Root roles are a special class of roles which bootstrap admin role capability in a decentralized
 *   manner rather than using a more centralized Ownable pattern.
 * @dev A standalone MUD System derived from OpenZeppelin's AccessControl implementation. Can be used to manage RBAC
 *   reference data for access control hook logic or access control structures for other MUD Systems.
 */
contract AccessControl is EveSystem {
  using Utils for bytes14;

  bytes32 private constant ROOT_NAME_BYTES32 = bytes32(abi.encodePacked("ROOT"));

  /**
   * @dev Modifier that checks if `account` is a member of a specific role with `roleId`. Reverts
   * with an {AccessControlUnauthorizedAccount} error, if the `account` is not a member.
   */
  modifier onlyRole(bytes32 roleId, address account) {
    _checkRole(roleId, account);
    _;
  }

  /**
   * @notice - Create a root role which corresponds to a single account which thereafter can be used to create other
   *  root linked roles.
   * @dev - Root roles have the following specific configuration, thereby allowing ANYONE to securely use access control
   *   with admin rights within a single address scope. This allows anyone to create a role that can be used as admin
   *   for other roles without having to use the Ownable.sol pattern (which only gives the contract
   *   deployer elevated admin permissions to start with).
   *   Root roles:
   *     - must be created via a call from a single account sourced from `world().initialMsgSender()`
   *     - assign themselves as thier own admin role
   *     - grant `world().initialMsgSender()` as thier first member
   *     - are the only roles which have a unique root value created and assigned as`world().initialMsgSender()`. All
   *         other created roles, inherit thier root value from thier admin role at the time of creation.
   *     - can be used to create other root linked roles by assigning as the admin role during creation.
   *         Subsequently, if any of those created roles (or thier children) go on to create other roles, any
   *         additional decendant role will also retain the orginating root role's rootId value
   *  A root role's name value is always the bytes32 of the "ROOT" string using abi.encodePacked()
   *  The roleId for any role (including root roles) is the hash of its root value and its name value.
   *  Throws an error {AccessControlBadConfirmation} if `callerConfirmation` is not equal to
   *    `world().initialMsgSender()`.
   *  Throws an error {AccessControlRoleAlreadyCreated} if this root role already exists.
   * @param callerConfirmation - the address of the `world().initialMsgSender()` caller, used to verify that the caller
   *   knows the address value used as the root value and name value, to generate roleId.
   * @return - the generated RootRoleData.
   */
  function createRootRole(address callerConfirmation) external returns (RootRoleData memory) {
    if (callerConfirmation != world().initialMsgSender()) {
      revert IAccessControlErrors.AccessControlBadConfirmation();
    }

    bytes32 roleId = keccak256(abi.encodePacked(callerConfirmation, ROOT_NAME_BYTES32));

    _createRole(roleId, ROOT_NAME_BYTES32, callerConfirmation, roleId);
    _grantRole(roleId, callerConfirmation);

    RootRoleData memory rootData = RootRoleData(ROOT_NAME_BYTES32, callerConfirmation, roleId);
    return rootData;
  }

  /**
   * @notice Create a new role with `name` linked to admin's root value and with `adminId` as the assigend admin
   *   role.
   * @dev Creates a new entry in the {Role} table assigning a root value, name value, admin value, and exsitence
   *   flag under the `roleId` key.
   * Only considers the first thirty-two bytes of the `name` string, since the role's stored name value is
   *   `bytes32(abi.encodePacked(name))`.
   * The root value of any decendant role (non-root role) is inherited from its admin role's root value at the
   *   time of creation. Ultimately, this is the address of the account that created admin's root role.
   * The `roleId` for any created role is calculated as the hash of its root value and the first 32 bytes of
   *   `abi.encodePacked(name)`.
   *
   * Throws the error {AccessControlUnauthorizedAccount} if `world().initialMsgSender()` is not a member of admin.
   * Throws the error {AccessControlRootAdminMismatch} if `rootAcctConfirmation` is not the root value of admin role `adminId`.
   * Throws the error {AccessControlRoleAlreadyCreated} if this role already exists (e.g. a role with `name` has
   *   already been created and linked with the `rootIdConfirmation` value as its rootId value).
   *
   * Emits a {RoleCreated} offchain table event.
   * Emits a {RoleAdminChanged} offchain table event.
   *
   * @param name - the name of the new role we want to create.
   * @param rootAcctConfirmation - the root value we intend to create this role under, used to verify that the caller
   *   knows the root value being used to create this role.
   * @param adminId - the admin role we want to assign for the created role.
   * @return - the generated roleId.
   */
  function createRole(
    string memory name,
    address rootAcctConfirmation,
    bytes32 adminId
  ) external onlyRole(adminId, world().initialMsgSender()) returns (bytes32) {
    address adminRootAcct = Role.getRoot(_namespace().roleTableId(), adminId);

    if (rootAcctConfirmation != adminRootAcct) {
      revert IAccessControlErrors.AccessControlRootAdminMismatch(rootAcctConfirmation, adminRootAcct, adminId);
    }
    bytes32 nameToBytes32 = bytes32(abi.encodePacked(name));
    bytes32 roleId = keccak256(abi.encodePacked(rootAcctConfirmation, nameToBytes32));

    _createRole(roleId, nameToBytes32, rootAcctConfirmation, adminId);

    return roleId;
  }

  /**
   * @notice Sets a new admin role for a role.
   * @dev Updates the adminId value in the {Role} table with `newAdminId` for the key `roleId`.
   *
   * Throws the error {AccessControlUnauthorizedAccount} if `world().initialMsgSender()` is not a member of the
   *   current admin role.
   * Throws the error {AccessControlAdminAlreadySet} if the admin roleId value is already set to `newAdminId`.
   *
   * Emits a {RoleAdminChanged} offchain table event.
   *
   * @param roleId - the role we want to set a new admin role for.
   * @param newAdminId - the new admin role to be assigned to this role.
   *
   */
  function transferRoleAdmin(
    bytes32 roleId,
    bytes32 newAdminId
  ) external onlyRole(Role.getAdmin(_namespace().roleTableId(), roleId), world().initialMsgSender()) {
    _setRoleAdmin(roleId, newAdminId);
  }

  /**
   * @notice Grants role membership to an account.
   * @dev Updates the {HasRole} table with hasRole = true for the key `roleId`,`account`.
   *
   * Throws the error {AccessControlUnauthorizedAccount} if `world().initialMsgSender()` is not a member of the
   *   current admin role.
   *
   * If `account` has not been already granted role membership, emits a {RoleGranted} offchain table event.
   *
   * @param roleId - the role to grant membership for.
   * @param account - the account to grant as a member.
   */
  function grantRole(
    bytes32 roleId,
    address account
  ) external onlyRole(Role.getAdmin(_namespace().roleTableId(), roleId), world().initialMsgSender()) {
    _grantRole(roleId, account);
  }

  /**
   * @notice Revokes role membership of an account.
   * @dev Updates the {HasRole} table with hasRole = false for the key `roleId`,`account`
   *
   * Throws the error {AccessControlUnauthorizedAccount} if world().initialMsgSender() is not a member of the current
   *   admin role.
   *
   * If `account` has role membership to be revoked, emits a {RoleRevoked} offchain table event.
   *
   * @param roleId - the role to revoke membership for
   * @param account - the account to remove as a member
   */
  function revokeRole(
    bytes32 roleId,
    address account
  ) external onlyRole(Role.getAdmin(_namespace().roleTableId(), roleId), world().initialMsgSender()) {
    _revokeRole(roleId, account);
  }

  /**
   * @notice Revokes role membership for the calling account.
   * @dev Updates the {HasRole} table with hasRole = false for the key `roleId`,`callerConfirmation`
   *
   * Throws the error {AccessControlBadConfirmation} if `callerConfirmation` is not equal to
   *   `world().initialMsgSender()`.
   *
   * If `callerConfirmation` has role membership to be revoked, emits a {RoleRevoked} offchain table event.
   *
   * @param roleId - the role to revoke membership for
   * @param callerConfirmation - the address of the `world().initialMsgSender()` caller, used to verify that the caller
   *   confirms their address to have thier role membership revoked.
   */
  function renounceRole(bytes32 roleId, address callerConfirmation) external {
    if (callerConfirmation != world().initialMsgSender()) {
      revert IAccessControlErrors.AccessControlBadConfirmation();
    }

    _revokeRole(roleId, callerConfirmation);
  }

  /**
   * @dev Returns `true` if `account` has been granted role membership for `roleId`.
   */
  function hasRole(bytes32 roleId, address account) external view returns (bool) {
    return HasRole.get(_namespace().hasRoleTableId(), roleId, account);
  }

  /**
   * @dev Returns the admin role that manages `roleId`. To change a role's admin, use {transferRoleAdmin}.
   */
  function getRoleAdmin(bytes32 roleId) external view returns (bytes32) {
    return Role.getAdmin(_namespace().roleTableId(), roleId);
  }

  /**
   * @dev Returns a `roleId` given a `rootAcct` and a `name`.
   */
  function getRoleId(address rootAcct, string calldata name) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(rootAcct, bytes32(abi.encodePacked(name))));
  }

  /**
   * @dev Returns `true` if `roleId` has been created
   */
  function roleExists(bytes32 roleId) external view returns (bool) {
    return Role.getExists(_namespace().roleTableId(), roleId);
  }

  /**
   * @dev Returns `true` if `roleId` has been created and is a root role
   */
  function isRootRole(bytes32 roleId) external view returns (bool) {
    RoleData memory roleData = Role.get(_namespace().roleTableId(), roleId);
    bytes32 rootRoleId = keccak256(abi.encodePacked(roleData.root, ROOT_NAME_BYTES32));
    if (roleData.exists == true && roleId == rootRoleId) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
   * is not a member of role.
   */
  function _checkRole(bytes32 roleId, address account) internal view virtual {
    if (!HasRole.get(_namespace().hasRoleTableId(), roleId, account)) {
      revert IAccessControlErrors.AccessControlUnauthorizedAccount(account, roleId);
    }
  }

  /**
   * @dev Creates a new role using the given `nameBytes`, `rootId`, and `adminId`.
   * Internal function without access restriction.
   * Emits a {RoleCreated} and {RoleAdminChanged} offchain table events.
   */
  function _createRole(bytes32 roleId, bytes32 nameBytes, address rootAcct, bytes32 adminId) internal virtual {
    if (Role.getExists(_namespace().roleTableId(), roleId)) {
      revert IAccessControlErrors.AccessControlRoleAlreadyCreated(roleId, nameBytes, rootAcct);
    }

    Role.set(_namespace().roleTableId(), roleId, true, nameBytes, rootAcct, bytes32(0x0));
    RoleCreated.set(_namespace().roleCreatedTableId(), roleId, nameBytes, rootAcct, adminId);

    _setRoleAdmin(roleId, adminId);
  }

  /**
   * @dev Sets `adminId` as `role`'s adminId value.
   * Internal function without access restriction.
   * Emits a {RoleAdminChanged} offchain table event.
   */
  function _setRoleAdmin(bytes32 roleId, bytes32 adminId) internal virtual {
    bytes32 previousAdminRole = Role.getAdmin(_namespace().roleTableId(), roleId);

    if (previousAdminRole == adminId) {
      revert IAccessControlErrors.AccessControlAdminAlreadySet(roleId, adminId);
    }

    Role.setAdmin(_namespace().roleTableId(), roleId, adminId);
    RoleAdminChanged.set(_namespace().roleAdminChangedTableId(), roleId, previousAdminRole, adminId);
  }

  /**
   * @dev Attempts to grant role membership to `account` and returns a boolean indicating if role membership was granted.
   * Internal function without access restriction.
   * Emits a {RoleGranted} offchain table event.
   */
  function _grantRole(bytes32 roleId, address account) internal virtual returns (bool) {
    if (!HasRole.get(_namespace().hasRoleTableId(), roleId, account)) {
      HasRole.set(_namespace().hasRoleTableId(), roleId, account, true);
      RoleGranted.set(_namespace().roleGrantedTableId(), roleId, account, world().initialMsgSender());
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Attempts to revoke role membership for `account` and returns a boolean indicating if role membership was revoked.
   * Internal function without access restriction.
   * Emits a {RoleRevoked} offchain table event.
   */
  function _revokeRole(bytes32 roleId, address account) internal virtual returns (bool) {
    if (HasRole.get(_namespace().hasRoleTableId(), roleId, account)) {
      HasRole.set(_namespace().hasRoleTableId(), roleId, account, false);
      RoleRevoked.set(_namespace().roleRevokedTableId(), roleId, account, world().initialMsgSender());
      return true;
    } else {
      return false;
    }
  }
}
