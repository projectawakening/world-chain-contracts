// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev External interface for AccessControl originating errors.
 */
interface IAccessControlErrors {

  /**
   * @dev `adminId` is already assigned to `roleId`
   */
  error AccessControlAdminAlreadySet(bytes32 roleId, bytes32 adminId);

  /**
   * @dev The caller of a function is not the expected one.
   *
   * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
   */
  error AccessControlBadConfirmation();

  /**
   * @dev `roleId` with `name` under `root` already exists 
   */
  error AccessControlRoleAlreadyCreated(bytes32 roleId, bytes32 name, bytes32 root);

  /**
   * @dev 'rootIdConfirmation' does not match the `rootId` value of `adminId`
   */
  error AccessControlRootAdminMismatch(bytes32 rootIdConfirmation, bytes32 rootId, bytes32 adminId);

  /**
   * @dev `account` is not a member of the required `roleId`
   */
  error AccessControlUnauthorizedAccount(address account, bytes32 roleId);
}