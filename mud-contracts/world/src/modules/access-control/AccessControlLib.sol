// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { RootRoleData } from "./types.sol";
import { IAccessControl } from "./interfaces/IAccessControl.sol";
import { IAccessControlErrors } from "./IAccessControlErrors.sol";
import { Utils } from "./Utils.sol";

/**
 * @title Access Control Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library AccessControlLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createRootRole(World memory world, address callerConfirmation) internal returns (RootRoleData memory) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.createRootRole, (callerConfirmation))
    );
    return abi.decode(returnData, (RootRoleData));
  }

  function createRole(
    World memory world,
    string memory name,
    address rootAcctConfirmation,
    bytes32 adminId
  ) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.createRole, (name, rootAcctConfirmation, adminId))
    );
    return abi.decode(returnData, (bytes32));
  }

  function transferRoleAdmin(World memory world, bytes32 roleId, bytes32 newAdminId) internal {
    world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.transferRoleAdmin, (roleId, newAdminId))
    );
  }

  function grantRole(World memory world, bytes32 roleId, address account) internal {
    world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.grantRole, (roleId, account))
    );
  }

  function revokeRole(World memory world, bytes32 roleId, address account) internal {
    world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.revokeRole, (roleId, account))
    );
  }

  function renounceRole(World memory world, bytes32 roleId, address callerConfirmation) internal {
    world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.renounceRole, (roleId, callerConfirmation))
    );
  }

  function hasRole(World memory world, bytes32 roleId, address account) internal returns (bool) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.hasRole, (roleId, account))
    );
    return abi.decode(returnData, (bool));
  }

  function getRoleAdmin(World memory world, bytes32 roleId) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.getRoleAdmin, (roleId))
    );
    return abi.decode(returnData, (bytes32));
  }

  function getRoleId(World memory world, address rootAcct, string memory name) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.getRoleId, (rootAcct, name))
    );
    return abi.decode(returnData, (bytes32));
  }

  function roleExists(World memory world, bytes32 roleId) internal returns (bool) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.roleExists, (roleId))
    );
    return abi.decode(returnData, (bool));
  }

  function isRootRole(World memory world, bytes32 roleId) internal returns (bool) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.isRootRole, (roleId))
    );
    return abi.decode(returnData, (bool));
  }
}
