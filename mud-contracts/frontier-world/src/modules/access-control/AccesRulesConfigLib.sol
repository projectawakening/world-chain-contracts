// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { IAccessRulesConfig } from "./IAccessRulesConfig.sol";
import { accessRulesConfigSystemId } from "./Utils.sol";

/**
 * @title Access Rules Config Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library AccessRulesConfigLib {
  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function setAccessControlRoles(uint256 entityId, uint256 configId, IAccessRulesConfig.RolesByContext rolesByContext) internal {
    world.iface.call(accessRulesConfigSystemId(world.namespace),
      abi.encodeCall(IAccessRulesConfig.setAccessControlRoles,
        (entityId, configId, rolesByContext)
      )
    );
  }

  function setEnforcementLevel(uint256 entityId, uint256 configId, IAccessRulesConfig.EnforcementLevel enforcementLevel) internal {
    world.iface.call(accessRulesConfigSystemId(world.namespace),
      abi.encodeCall(IAccessRulesConfig.setEnforcementLevel,
        (entityId, configId, enforcementLevel)
      )
    );
  }

  function supportsInterface(World memory world, bytes4 interfaceId) internal returns(bool) {
    bytes memory returnData = world.iface.call(accessRulesConfigSystemId(world.namespace),
      abi.encodeCall(IAccessRulesConfig.supportsInterface,
        (interfaceId)
      )
    );
    return abi.decode(returnData, (bool));
  }
}