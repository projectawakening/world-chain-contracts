// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { EntityRecord, EntityRecordMetadata, EntityRecordMetadataData } from "../../codegen/index.sol";
import { EntityRecordData, EntityMetadata } from "./types.sol";

/**
 * @title EntityRecordSystem
 * @author CCP Games
 * EntityRecordSystem stores an in game entity record on chain.
 */
contract EntityRecordSystem is System {
  /**
   * @dev creates a new entity record
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param entityRecord is the EnityRecordData struct with all the data needed to create a new entity record
   */
  function createEntityRecord(uint256 smartObjectId, EntityRecordData memory entityRecord) public {
    EntityRecord.set(smartObjectId, entityRecord.itemId, entityRecord.typeId, entityRecord.volume, true);
  }

  /**
   * @dev creates the metadata for an entity record
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param entityRecordMetadata is the EntityMetadata struct with all the data needed to create a new entity record metadata
   */
  function createEntityRecordMetadata(uint256 smartObjectId, EntityMetadata memory entityRecordMetadata) public {
    EntityRecordMetadata.set(
      smartObjectId,
      entityRecordMetadata.name,
      entityRecordMetadata.dappURL,
      entityRecordMetadata.description
    );
  }

  /**
   * @dev sets the name of an entity
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param name the name of the entity
   */
  function setName(uint256 smartObjectId, string memory name) public {
    EntityRecordMetadata.setName(smartObjectId, name);
  }

  /**
   * @dev sets the dappURL of an entity
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param dappURL the dappURL of the entity
   */
  function setDappURL(uint256 smartObjectId, string memory dappURL) public {
    EntityRecordMetadata.setDappURL(smartObjectId, dappURL);
  }

  /**
   * @dev sets the description of an entity
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param description the description of the entity
   */
  function setDescription(uint256 smartObjectId, string memory description) public {
    EntityRecordMetadata.setDescription(smartObjectId, description);
  }
}
