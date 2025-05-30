// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { CallAccess } from "../../codegen/tables/CallAccess.sol";

/**
 * @title CallAccessSystem
 * @author CCP Games
 * @notice Update CallAccess table.
 * @dev This system should be registed with closed access, so it has the same access control as its table.
 */
contract CallAccessSystem is System {
  function addCallAccess(
    ResourceId systemId, bytes4 functionId, address caller
  ) public {
    CallAccess.set(systemId, functionId, caller, true);
  }

  function removeCallAccess(
    ResourceId systemId, bytes4 functionId, address caller
  ) public {
    CallAccess.deleteRecord(systemId, functionId, caller);
  }
}
