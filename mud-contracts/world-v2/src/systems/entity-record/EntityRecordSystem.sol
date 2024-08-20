// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { EntityRecord, EntityRecordMetadata } from "../../codegen/index.sol";

/**
 * @title EntityRecordSystem
 * @author CCP Games
 * EntityRecordSystem stores an in game entity record on chain.
 */
contract EntityRecordSystem is System {
  /**
   * @dev creates a new entity record
   * @param entityId the id of a in game entity referred as smart object id
   * @param itemId the id of a item in game
   * @param volume the volume of the item
   */
  function createEntityRecord(uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) public {
    EntityRecord.set(entityId, itemId, typeId, volume, true);
  }

  /**
   * @dev creates the metadata for an entity record
   * @param entityId the id of a in game entity referred as smart object id
   * @param name the name of the entity
   * @param dappURL stores the URL where the dapp for an entity is hosted
   * @param description the description of the entity
   */
  function createEntityRecordMetadata(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public {
    EntityRecordMetadata.set(entityId, name, dappURL, description);
  }

  /**
   * @dev sets the name of an entity
   * @param entityId the id of a in game entity referred as smart object id
   * @param name the name of the entity
   */
  function setName(uint256 entityId, string memory name) public {
    EntityRecordMetadata.setName(entityId, name);
  }

  /**
   * @dev sets the dappURL of an entity
   * @param entityId the id of a in game entity referred as smart object id
   * @param dappURL the dappURL of the entity
   */
  function setDappURL(uint256 entityId, string memory dappURL) public {
    EntityRecordMetadata.setDappURL(entityId, dappURL);
  }

  /**
   * @dev sets the description of an entity
   * @param entityId the id of a in game entity referred as smart object id
   * @param description the description of the entity
   */
  function setDescription(uint256 entityId, string memory description) public {
    EntityRecordMetadata.setDescription(entityId, description);
  }
}
