//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { Characters, CharacterToken } from "../../codegen/index.sol";
import { IEntityRecordSystem } from "../../codegen/world/IEntityRecordSystem.sol";
import { CharactersByAddress } from "../../codegen/tables/CharactersByAddress.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordData, EntityMetadata } from "../entity-record/types.sol";
import { IERC721Mintable } from "../eve-erc721-puppet/IERC721Mintable.sol";
import { EveSystem } from "../EveSystem.sol";

import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";

contract SmartCharacterSystem is EveSystem {
  using EntityRecordUtils for bytes14;

  error SmartCharacter_ERC721AlreadyInitialized();
  error SmartCharacter_AlreadyCreated(address characterAddress, uint256 characterId);
  error SmartCharacterDoesNotExist(uint256 characterId);

  /**
   * @notice Register a new character token
   * @param tokenAddress The address of the token to register
   */
  function registerCharacterToken(address tokenAddress) public {
    if (CharacterToken.get() != address(0)) {
      revert SmartCharacter_ERC721AlreadyInitialized();
    }
    CharacterToken.set(tokenAddress);
  }

  /**
   * @notice Create a new character
   * @param characterId The ID of the character
   * @param characterAddress The address of the character
   * @param entityRecord The entity record data
   * @param entityRecordMetadata The entity record metadata
   */
  function createCharacter(
    uint256 characterId,
    address characterAddress,
    uint256 tribeId,
    EntityRecordData memory entityRecord,
    EntityMetadata memory entityRecordMetadata
  ) public {
    uint256 createdAt = block.timestamp;

    // enforce one-to-one mapping
    if (CharactersByAddress.get(characterAddress) != 0) {
      revert SmartCharacter_AlreadyCreated(characterAddress, characterId);
    }

    Characters.set(characterId, characterAddress, tribeId, createdAt);
    CharactersByAddress.set(characterAddress, characterId);

    //Save the entity record in EntityRecord Module
    ResourceId entityRecordSystemId = EntityRecordUtils.entityRecordSystemId();
    world().call(
      entityRecordSystemId,
      abi.encodeCall(EntityRecordSystem.createEntityRecord, (characterId, entityRecord))
    );
    world().call(
      entityRecordSystemId,
      abi.encodeCall(EntityRecordSystem.createEntityRecordMetadata, (characterId, entityRecordMetadata))
    );

    //Mint a new character token
    IERC721Mintable(CharacterToken.get()).mint(characterAddress, characterId);
  }

  function updateTribeId(uint256 characterId, uint256 tribeId) public {
    if (Characters.getTribeId(characterId) == 0) {
      revert SmartCharacterDoesNotExist(characterId);
    }
    Characters.setTribeId(characterId, tribeId);
  }
}
