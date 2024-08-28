// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ISmartCharacter } from "./interfaces/ISmartCharacter.sol";
import { EntityRecordOffchainTableData } from "../../codegen/tables/EntityRecordOffchainTable.sol";

import { SmartObjectData, EntityRecordData } from "./types.sol";
import { Utils } from "./Utils.sol";

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
    uint256 corpId,
    EntityRecordData memory entityRecord,
    EntityRecordOffchainTableData memory entityRecordOffchain,
    string memory tokenCid
  ) internal {
    world.iface.call(
      world.namespace.smartCharacterSystemId(),
      abi.encodeCall(
        ISmartCharacter.createCharacter,
        (characterId, characterAddress, corpId, entityRecord, entityRecordOffchain, tokenCid)
      )
    );
  }

  function registerERC721Token(World memory world, address tokenAddress) internal {
    world.iface.call(
      world.namespace.smartCharacterSystemId(),
      abi.encodeCall(ISmartCharacter.registerERC721Token, (tokenAddress))
    );
  }

  function setCharClassId(World memory world, uint256 classId) internal {
    world.iface.call(
      world.namespace.smartCharacterSystemId(),
      abi.encodeCall(ISmartCharacter.setCharClassId, (classId))
    );
  }
}
