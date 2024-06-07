// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

/**
 * @title IAccessControl
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IAccessControl {
  function eveworld__setAccessListByRole(bytes32 accessRoleId, address[] memory accessList) external;

  function eveworld__setAccessEnforcement(bytes32 target, bool isEnforced) external;
}
