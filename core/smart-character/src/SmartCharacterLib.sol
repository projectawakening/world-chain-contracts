// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { Utils } from "./utils.sol";

/**
 * @title ISmartCharacter system
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 * Needs to match corresponding System exhaustively
 */
interface ISmartCharacter {
  function createCharacter(string memory name) external returns (bytes32 key);
}

/**
 * @title Smart Character Library (makes interacting with the underlying Systems cleaner)
 * Works similarly to direct calls to world, without having to deal with dynamic method's function selectors due to namespacing.
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library SmartCharacterLib {
  using Utils for bytes14;

  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  // SmartCharacter methods
  function createCharacter(World memory world, string memory name) internal returns (bytes32 key) {
    bytes memory returnData = world.iface.call(world.namespace.smartCharacterSystemId(),
      abi.encodeCall(ISmartCharacter.createCharacter,
        (name)
      )
    );
    return abi.decode(returnData, (bytes32));
  }
}