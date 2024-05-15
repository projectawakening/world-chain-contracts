// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { IAccessControl } from "./IAccessControl.sol";
import { accessControlSystemId } from "./Utils.sol";

/**
 * @title Access Control Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library AccessControlLib {
  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function createRootRole(address callerConfirmation) internal returns(bytes32) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.createRootRole,
        (callerConfirmation)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function createRole(World memory world, string name, bytes32 rootIdConfirmation, bytes32 adminId) internal returns(bytes32) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.createRole,
        (name, rootIdConfirmation, adminId)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function transferRoleAdmin(bytes32 roleId, bytes32 newAdminId) internal {
    world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.transferRoleAdmin,
        (rolId, newAdminId)
      )
    );
  }

  function grantRole(World memory world, bytes32 roleId, address account) internal {
    world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.grantRole,
        (roleId, account)
      )
    );
  }

  function revokeRole(World memory world, bytes32 roleId, address account) internal {
    world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.revokeRole,
        (roleId, account)
      )
    );
  }

  function renounceRole(World memory world, bytes32 roleId, address callerConfirmation) internal {
    world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.renounceRole,
        (roleId, callerConfirmation)
      )
    );
  }

  function hasRole(World memory world, bytes32 roleId, address account) internal returns (bool) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.hasRole,
        (roleId, account)
      )
    );
    return abi.decode(returnData, (bool));
  }

  function getRoleAdmin(World memory world, bytes32 roleId) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.getRoleAdmin,
        (roleId)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function getRoleIdByRootId(bytes32 rootId, string name) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.getRoleIdByRootId,
        (rootId, name)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function getRoleIdByRootAcct(address rootAcct string name) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.getRoleIdByRootAcct,
        (rootAcct, name)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function supportsInterface(World memory world, bytes4 interfaceId) internal returns(bool) {
    bytes memory returnData = world.iface.call(accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.supportsInterface,
        (interfaceId)
      )
    );
    return abi.decode(returnData, (bool));
  }
}