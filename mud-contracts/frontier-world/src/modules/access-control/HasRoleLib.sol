// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { RootRoleData } from "./types.sol";
import { IAccessControl } from "./interfaces/IAccessControl.sol";
import { Utils } from "./Utils.sol";

/**
 * @title Access Control Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library HasRoleLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function hasRole(World memory world, bytes32 roleId, address account) internal returns (bool) {
    bytes memory returnData = world.iface.call(
      world.namespace.accessControlSystemId(),
      abi.encodeCall(IAccessControl.hasRole,
        (roleId, account)
      )
    );
    return abi.decode(returnData, (bool));
  }

}