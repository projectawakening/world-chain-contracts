// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

interface IAccessSystemErrors {
  error AccessSystem_NoPermission(address sender, bytes32 roleId);

  error AccessSystem_InvalidRoleId();

  error AccessSystem_AccessConfigDenied();
}
