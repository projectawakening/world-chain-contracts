//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { Characters, CharacterToken } from "../../codegen/index.sol";
import { CharactersByAddress } from "../../codegen/tables/CharactersByAddress.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordData, EntityMetadata } from "../entity-record/types.sol";
import { IERC721Mintable } from "../eve-erc721-puppet/IERC721Mintable.sol";

import { EntityRecord } from "../../codegen/tables/EntityRecord.sol";
import { Initialize } from "../../codegen/index.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

contract SmartCharacterSystem is SmartObjectFramework {
  error SmartCharacter_ERC721AlreadyInitialized();
  error SmartCharacter_AlreadyCreated(address characterAddress, uint256 characterId);
  error SmartCharacterDoesNotExist(uint256 characterId);

  /**
   * @notice Register a new character token
   * @param tokenAddress The address of the token to register
   */
  function registerCharacterToken(address tokenAddress) public context access(0) scope(0) {
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
  ) public context access(characterId) scope(getSmartCharacterClassId()) {
    uint256 createdAt = block.timestamp;

    // enforce one-to-one mapping
    if (CharactersByAddress.get(characterAddress) != 0) {
      revert SmartCharacter_AlreadyCreated(characterAddress, characterId);
    }

    entitySystem.instantiate(getSmartCharacterClassId(), characterId, characterAddress);

    Characters.set(characterId, characterAddress, tribeId, createdAt);
    CharactersByAddress.set(characterAddress, characterId);

    //Save the entity record in EntityRecord Module
    entityRecordSystem.createEntityRecord(characterId, entityRecord);
    entityRecordSystem.createEntityRecordMetadata(characterId, entityRecordMetadata);

    //Mint a new character token
    IERC721Mintable(CharacterToken.get()).mint(characterAddress, characterId);
  }

  function updateTribeId(uint256 characterId, uint256 tribeId) public context access(characterId) scope(characterId) {
    if (Characters.getTribeId(characterId) == 0) {
      revert SmartCharacterDoesNotExist(characterId);
    }
    Characters.setTribeId(characterId, tribeId);
  }

  function getSmartCharacterClassId() public view returns (uint256) {
    return Initialize.get(smartCharacterSystem.toResourceId());
  }
}
