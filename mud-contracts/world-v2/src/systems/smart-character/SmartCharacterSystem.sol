//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";

import { Characters, CharacterToken } from "../../codegen/index.sol";
import { IEntityRecordSystem } from "../../codegen/world/IEntityRecordSystem.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordData, EntityMetadata } from "../entity-record/types.sol";
import { EveSystem } from "../EveSystem.sol";

import { console } from "forge-std/console.sol";

contract SmartCharacterSystem is EveSystem {
  /**
   * @notice Register a new character token
   * @param tokenAddress The address of the token to register
   */
  function registerCharacterToken(address tokenAddress) public {
    if (CharacterToken.get() != address(0)) {
      //throw error
    }
    CharacterToken.set(tokenAddress);
  }

  /**
   * @notice Create a new character
   * @param characterId The ID of the character
   * @param characterAddress The address of the character
   * @param entityRecord The entity record data
   * @param entityRecordMetadata The entity record metadata
   * @param tokenCid The CID of the token
   */
  function createCharacter(
    uint256 characterId,
    address characterAddress,
    EntityRecordData memory entityRecord,
    EntityMetadata memory entityRecordMetadata,
    string memory tokenCid
  ) public {
    uint256 createdAt = block.timestamp;
    Characters.set(characterId, characterAddress, createdAt);

    //Save the entity record in EntityRecord Module
    bytes4 functionSelector = IEntityRecordSystem.eveworld__createEntityRecord.selector;
    ResourceId systemId = FunctionSelectors.getSystemId(functionSelector);

    world().call(systemId, abi.encodeCall(EntityRecordSystem.createEntityRecord, entityRecord));

    functionSelector = IEntityRecordSystem.eveworld__createEntityRecordMetadata.selector;
    systemId = FunctionSelectors.getSystemId(functionSelector);

    world().call(systemId, abi.encodeCall(EntityRecordSystem.createEntityRecordMetadata, entityRecordMetadata));

    //Mint a new character token
    IERC721Mintable(CharacterToken.get()).mint(characterAddress, characterId);

    //TODO: Store the tokenCid
  }
}
