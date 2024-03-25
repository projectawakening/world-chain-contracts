// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { EntityRecordTableData } from "../../codegen/tables/EntityRecordTable.sol";

import { SmartObjectData } from "./types.sol";
import { Utils } from "./Utils.sol";
import { ISmartCharacter } from "./interfaces/ISmartCharacter.sol";

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

  function createCharacter(
    World memory world,
    uint256 characterId,
    address characterAddress,
    EntityRecordTableData memory entityRecord,
    string memory tokenCid
  ) internal {
    world.iface.call(
      world.namespace.smartCharacterSystemId(),
      abi.encodeCall(ISmartCharacter.createCharacter, (characterId, characterAddress, entityRecord, tokenCid))
    );
  }

  function registerERC721Token(World memory world, address tokenAddress) internal {
    world.iface.call(
      world.namespace.smartCharacterSystemId(),
      abi.encodeCall(ISmartCharacter.registerERC721Token, (tokenAddress))
    );
  }
}