// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

interface IAccessErrors {
  error Access_NoPermission(address sender, bytes32 roleId);

  error Access_InvalidRoleId();

  error Access_AccessConfigAccessDenied();
}
