// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { IAccessRulesConfig } from "./interfaces/IAccessRulesConfig.sol";
import { RolesByContext, EnforcementLevel } from "./types.sol";
import { Utils } from "./Utils.sol";

/**
 * @title Access Rules Config Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library AccessRulesConfigLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function setAccessControlRoles(World memory world, uint256 entityId, uint256 configId, RolesByContext memory rolesByContext) internal {
    world.iface.call(
      world.namespace.accessRulesConfigSystemId(),
      abi.encodeCall(IAccessRulesConfig.setAccessControlRoles,
        (entityId, configId, rolesByContext)
      )
    );
  }

  function setEnforcementLevel(World memory world, uint256 entityId, uint256 configId, EnforcementLevel enforcementLevel) internal {
    world.iface.call(
      world.namespace.accessRulesConfigSystemId(),
      abi.encodeCall(IAccessRulesConfig.setEnforcementLevel,
        (entityId, configId, enforcementLevel)
      )
    );
  }
}