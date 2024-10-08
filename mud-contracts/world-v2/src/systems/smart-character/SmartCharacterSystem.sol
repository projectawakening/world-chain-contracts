//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { Characters, CharacterToken } from "../../codegen/index.sol";
import { IEntityRecordSystem } from "../../codegen/world/IEntityRecordSystem.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordData, EntityMetadata } from "../entity-record/types.sol";
import { IERC721Mintable } from "../eve-erc721-puppet/IERC721Mintable.sol";
import { EveSystem } from "../EveSystem.sol";

import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";
import { StaticDataUtils } from "../static-data/StaticDataUtils.sol";
import { ISmartCharacterErrors } from "./ISmartCharacterErrors.sol";

import "forge-std/console.sol";

contract SmartCharacterSystem is EveSystem {
  using StaticDataUtils for bytes14;
  using EntityRecordUtils for bytes14;

  /**
   * @notice Register a new character token
   * @param tokenAddress The address of the token to register
   */
  function registerCharacterToken(address tokenAddress) public {
    if (CharacterToken.get() != address(0)) {
      revert ISmartCharacterErrors.SmartCharacter_ERC721AlreadyInitialized();
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
    EntityRecordData memory entityRecord,
    EntityMetadata memory entityRecordMetadata
  ) public {
    uint256 createdAt = block.timestamp;
    Characters.set(characterId, characterAddress, createdAt);

    // Save the entity record in EntityRecord Module
    ResourceId entityRecordSystemId = EntityRecordUtils.entityRecordSystemId();
    world().call(entityRecordSystemId, abi.encodeCall(EntityRecordSystem.createEntityRecord, entityRecord));
    world().call(
      entityRecordSystemId,
      abi.encodeCall(EntityRecordSystem.createEntityRecordMetadata, entityRecordMetadata)
    );

    ResourceId staticDataSystemId = StaticDataUtils.staticDataSystemId();

    //Mint a new character token
    IERC721Mintable(CharacterToken.get()).mint(characterAddress, characterId);
  }
}
