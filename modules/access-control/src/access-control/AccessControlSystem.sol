// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldContextConsumer } from "@latticexyz/world/src/WorldContext.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";
import { IWorld as IWorldCore } from "@eve/smart-object-framework/src/codegen/world/IWorld.sol";
import { IAccessControl, IAccessControlMUD } from "./IAccessControlMUD.sol";

import { HasRole } from "../codegen/tables/HasRole.sol";
import { RoleAdmin } from "../codegen/tables/RoleAdmin.sol";
import { EntityToRole } from "../codegen/tables/EntityToRole.sol";
import { EntityToRoleAND } from "../codegen/tables/EntityToRoleAND.sol";
import { EntityToRoleOR } from "../codegen/tables/EntityToRoleOR.sol";

import { _hasRoleTableId, _roleAdminTableId, _entityToRoleTableId, _entityToRoleANDTableId, _entityToRoleORTableId, _accessControlSystemId } from "./utils.sol";

/**
 * @dev RBAC System derived from OpenZeppelin's RBAC implementation
 * so that it should be able to support ERC-165 later on
 */
contract AccessControlSystem is EveSystem, IAccessControlMUD {
  using WorldResourceIdInstance for ResourceId;

  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

  /**
   * @dev Modifier that checks that an account has a specific role. Reverts
   * with an {AccessControlUnauthorizedAccount} error including the required role.
   */
  modifier onlyRole(bytes32 role) {
    _checkRole(role);
    _;
  }

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding an `onlyRole(bytes32 role)` modifier to that method
   * @param entityId entity targeted by the Access Control hook
   */
  function onlyRoleHook(uint256 entityId) external view {
    bytes32 role = EntityToRole.get(_entityToRoleTableId(_namespace()), entityId);
    if(role == 0) revert AccessControlHookUnititialized(entityId);

    if(!(hasRole(role, _msgSender()))) {
      revert AccessControlUnauthorizedAccount(_msgSender(), role);
    }
  }

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding a `require(hasRole(roles[0]) && hasRole(roles[1]) && ...for role.length...)` to that method
   * @param entityId entity targeted by the Access Control hook
   */
  function onlyRoleANDHook(uint256 entityId) external view {
    bytes32[] memory roles = EntityToRoleAND.get(_entityToRoleANDTableId(_namespace()), entityId);
    if(roles.length == 0) revert AccessControlHookANDUnititialized(entityId);

    for(uint i=0; i < roles.length; i++) {
      if(!(hasRole(roles[i], _msgSender()))) {
        revert AccessControlUnauthorizedAccount(_msgSender(), roles[i]);
      }
    }
  }

  /**
   * @dev this method is meant to be added as a hook to other methods doing entity-related actions
   * Equivalent to adding a `require(hasRole(roles[0]) || hasRole(roles[1]) || ...for role.length...)` to that method
   * @param entityId entity targeted by the Access Control hook
   */
  function onlyRoleORHook(uint256 entityId) external view {
    bytes32[] memory roles = EntityToRoleOR.get(_entityToRoleORTableId(_namespace()), entityId);
    if(roles.length == 0) revert AccessControlHookORUnititialized(entityId);

    for(uint i=0; i < roles.length; i++) {
      if(hasRole(roles[i], _msgSender())) {
        return;
      }
    }
    // can only revert one of the many possible roles available, let's just say we revert the 1st array member
    revert AccessControlUnauthorizedAccount(_msgSender(), roles[0]);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public pure virtual override(IAccessControlMUD, WorldContextConsumer) returns (bool) {
    return interfaceId == type(IAccessControl).interfaceId 
        || interfaceId == type(IAccessControlMUD).interfaceId
        || super.supportsInterface(interfaceId);
  }

  /**
   * @dev Returns `true` if `account` has been granted `role`.
   */
  function hasRole(bytes32 role, address account) public view returns (bool) {
    return HasRole.get(_hasRoleTableId(_namespace()), role, account);
  }

  /**
   * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
   * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
   */
  function _checkRole(bytes32 role) internal view virtual {
    _checkRole(role, _msgSender());
  }

  /**
   * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
   * is missing `role`.
   */
  function _checkRole(bytes32 role, address account) internal view virtual {
    if (!HasRole.get(_hasRoleTableId(_namespace()), role, account)) {
      revert AccessControlUnauthorizedAccount(account, role);
    }
  }

  /**
   * @dev Returns the admin role that controls `role`. See {grantRole} and
   * {revokeRole}.
   *
   * To change a role's admin, use {AccessControl-_setRoleAdmin}.
   */
  function getRoleAdmin(bytes32 role) external view returns (bytes32) {
    return RoleAdmin.get(_roleAdminTableId(_namespace()), role);
  }

  /**
   * @dev Grants `role` to `account`.
   *
   * If `account` had not been already granted `role`, emits a {RoleGranted}
   * event.
   *
   * Requirements:
   *
   * - the caller must have ``role``'s admin role.
   */
  function grantRole(bytes32 role, address account) 
    external 
    onlyRole(RoleAdmin.get(_roleAdminTableId(_namespace()), role))
  {
    _grantRole(role, account);
  }

  /**
   * @dev Revokes `role` from `account`.
   *
   * If `account` had been granted `role`, emits a {RoleRevoked} event.
   *
   * Requirements:
   *
   * - the caller must have ``role``'s admin role.
   */
  function revokeRole(bytes32 role, address account)
    external
    onlyRole(RoleAdmin.get(_roleAdminTableId(_namespace()), role))
  {
    _revokeRole(role, account);
  }

  /**
   * @dev Revokes `role` from the calling account.
   *
   * Roles are often managed via {grantRole} and {revokeRole}: this function's
   * purpose is to provide a mechanism for accounts to lose their privileges
   * if they are compromised (such as when a trusted device is misplaced).
   *
   * If the calling account had been granted `role`, emits a {RoleRevoked}
   * event.
   *
   * Requirements:
   *
   * - the caller must be `callerConfirmation`.
   */
  function renounceRole(bytes32 role, address callerConfirmation) external {
    if (callerConfirmation != _msgSender()) {
      revert AccessControlBadConfirmation();
    }

    _revokeRole(role, callerConfirmation);
  }

  /**
   * @dev Sets `adminRole` as ``role``'s admin role.
   * TODO: figure out how exactly we want to enact Role Admin changes in the EveSystem context
   * 
   * Emits a {RoleAdminChanged} event.
   */
  function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
    bytes32 previousAdminRole = RoleAdmin.get(_roleAdminTableId(_namespace()), role);
    RoleAdmin.set(_roleAdminTableId(_namespace()), role, adminRole);
    emit RoleAdminChanged(role, previousAdminRole, adminRole);
  }

  /**
   * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
   *
   * Internal function without access restriction.
   *
   * May emit a {RoleGranted} event.
   */
  function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
    if (!HasRole.get(_hasRoleTableId(_namespace()), role, account)) {
      HasRole.set(_hasRoleTableId(_namespace()), role, account, true);
      emit RoleGranted(role, account, _msgSender());
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
   *
   * Internal function without access restriction.
   *
   * May emit a {RoleRevoked} event.
   */
  function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
    if (HasRole.get(_hasRoleTableId(_namespace()), role, account)) {
      HasRole.set(_hasRoleTableId(_namespace()), role, account, false);
      emit RoleRevoked(role, account, _msgSender());
      return true;
    } else {
      return false;
    }
  }

  /**
    * @dev not in the AccessControl specs, specific function to claim a singletonRole
    * Allows us to bootstrap RBAC to a certain address
    * Creates a role ( == bytes32(_msgSender()) ) and assign itself as its own role admin
    */
  function claimSingletonRole(address callerConfirmation) external {
    if (callerConfirmation != _msgSender()) {
      revert AccessControlBadConfirmation();
    }

    bytes32 singletonRole = bytes32(uint256(uint160(_msgSender())));
    if(HasRole.get(_hasRoleTableId(_namespace()), singletonRole, _msgSender())) {
      revert AccessControlSingletonRoleExists(_msgSender());
    }
    _setRoleAdmin(singletonRole, singletonRole);
    _grantRole(singletonRole, _msgSender());
  }

  /**
   * @dev create a new role (role needs to be unused)
   * throws an error {AccessControlRoleAlreadyCreated} if 'role' already exists (e.g. has an admin already)
   * throws an error {AccessControlUnauthorizedAccount} if _msgSender isn't 'roleAdmin'
   * @param role the role we want to create
   * @param roleAdmin the role admin we want to assign to it (msgSender needs to have it)
   */
  function createRole(bytes32 role, bytes32 roleAdmin) external {
    if(!(RoleAdmin.get(_roleAdminTableId(_namespace()), role) == DEFAULT_ADMIN_ROLE)) {
      revert AccessControlRoleAlreadyCreated(role, _msgSender());
    }
    if(!HasRole.get(_hasRoleTableId(_namespace()), roleAdmin, _msgSender())) {
      revert AccessControlUnauthorizedAccount(_msgSender(), roleAdmin);
    }

    _setRoleAdmin(role, roleAdmin);
  }

  /**
   * @dev Config function for `onlyRoleHook` method
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param role the role we want to assing to it
   */
  function setOnlyRoleHookConfig(uint256 entityId, bytes32 role) 
    hookable(entityId, _systemId(), abi.encode(entityId)) 
    external
  {
    EntityToRole.set(_entityToRoleTableId(_namespace()), entityId, role);
  }

  /**
   * @dev Config function for `onlyRoleANDHook` method
   * Note that the only way to update the OnlyRoleAND array is to give an entirely new one; no in-array item updating methods for now
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param roles the role we want to assing to it
   */
  function setOnlyRoleANDConfig(uint256 entityId, bytes32[] calldata roles)
    hookable(entityId, _systemId(), abi.encode(entityId)) 
    external
  {
    EntityToRoleAND.set(_entityToRoleANDTableId(_namespace()), entityId, roles);
  }

  /**
   * @dev Config function for `onlyRoleANDHook` method
   * Note that the only way to update the OnlyRoleAND array is to give an entirely new one; no in-array item updating methods for now
   * @param entityId the entityId we want to set access control's onlyRole rules for
   * @param roles the role we want to assing to it
   */
  function setOnlyRoleORConfig(uint256 entityId, bytes32[] calldata roles)
    hookable(entityId, _systemId(), abi.encode(entityId)) 
    external
  {
    EntityToRoleAND.set(_entityToRoleORTableId(_namespace()), entityId, roles);
  }

  function _namespace() internal view returns (bytes14 namespace) {
    ResourceId systemId = SystemRegistry.get(address(this));
    return systemId.getNamespace();
  }

  function _systemId() internal view returns (ResourceId) {
    return _accessControlSystemId(_namespace());
  }
}
