// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { IAccessControl, IAccessControlMUD } from "./IAccessControlMUD.sol";
import { _accessControlSystemId } from "./utils.sol";

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

  function supportsInterface(World memory world, bytes4 interfaceId) internal returns(bool) {
    bytes memory returnData = world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.supportsInterface,
        (interfaceId)
      )
    );
    return abi.decode(returnData, (bool));
  }

  function claimSingletonRole(World memory world, address callerConfirmation) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.claimSingletonRole,
        (callerConfirmation)
      )
    );
  }

  function createRole(World memory world, bytes32 role, bytes32 roleAdmin) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.createRole,
        (role, roleAdmin)
      )
    );
  }

  function hasRole(World memory world, bytes32 role, address account) internal returns (bool) {
    bytes memory returnData = world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.hasRole,
        (role, account)
      )
    );
    return abi.decode(returnData, (bool));
  }

  function getRoleAdmin(World memory world, bytes32 role) internal returns (bytes32) {
    bytes memory returnData = world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.getRoleAdmin,
        (role)
      )
    );
    return abi.decode(returnData, (bytes32));
  }

  function grantRole(World memory world, bytes32 role, address account) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.grantRole,
        (role, account)
      )
    );
  }

  function revokeRole(World memory world, bytes32 role, address account) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.revokeRole,
        (role, account)
      )
    );
  }

  function renounceRole(World memory world, bytes32 role, address callerConfirmation) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControl.renounceRole,
        (role, callerConfirmation)
      )
    );
  }

  function setOnlyRoleConfig(World memory world, uint256 entityId, bytes32 role) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.setOnlyRoleConfig,
        (entityId, role)
      )
    );
  }

  function setOnlyRoleANDConfig(World memory world, uint256 entityId, bytes32[] calldata roles) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.setOnlyRoleANDConfig,
        (entityId, roles)
      )
    );
  }

  function setOnlyRoleORConfig(World memory world, uint256 entityId, bytes32[] calldata roles) internal {
    world.iface.call(_accessControlSystemId(world.namespace),
      abi.encodeCall(IAccessControlMUD.setOnlyRoleORConfig,
        (entityId, roles)
      )
    );
  }
}