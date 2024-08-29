// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { IWorld } from "../../../codegen/world/IWorld.sol";

/**
 * @title EveSystem
 * @author CCP Games
 * @notice This is the base system to be inherited by all other systems.
 * @dev Consider combining this with the SmartObjectSystem which is extended by all systems.
 */
contract EveSystem is System {
  /**
   * @notice Get the world instance
   * @return The IWorld instance
   */
  function world() internal view returns (IWorld) {
    return IWorld(_world());
  }
}
