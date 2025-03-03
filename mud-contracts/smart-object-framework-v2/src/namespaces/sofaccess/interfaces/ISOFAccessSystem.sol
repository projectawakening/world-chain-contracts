// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ISOFAccessSystem
 * @dev An interface for the SOF access control logic functionality
 */
interface ISOFAccessSystem {
  function allowDirectAccessRoleOnly(uint256 entityId, bytes memory targetCallData) external view;
  function allowDirectClassAccessRoleOnly(uint256 entityId, bytes memory targetCallData) external view;
  function allowClassScopedSystemOnly(uint256 entityId, bytes memory targetCallData) external view;
  function allowClassScopedSystemOrDirectAccessRole(uint256 entityId, bytes memory targetCallData) external view;
  function allowClassScopedSystemOrDirectClassAccessRole(uint256 entityId, bytes memory targetCallData) external view;
  function allowCallAccessOnly(uint256 entityId, bytes memory targetCallData) external view;
  function allowCallAccessOrDirectAccessRole(uint256 entityId, bytes memory targetCallData) external view;
  function allowCallAccessOrClassScopedSystem(uint256 entityId, bytes memory targetCallData) external view;
  function allowCallAccessOrClassScopedSystemOrDirectAccessRole(
    uint256 entityId,
    bytes memory targetCallData
  ) external view;
  function allowCallAccessOrClassScopedSystemOrDirectClassAccessRole(
    uint256 entityId,
    bytes memory targetCallData
  ) external view;

  error SOFAccess_AccessDenied(uint256 entityId, address caller);
}
