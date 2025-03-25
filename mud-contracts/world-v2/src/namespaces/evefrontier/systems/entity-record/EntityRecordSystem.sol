// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
import { EntityRecord, EntityRecordMetadata } from "../../codegen/index.sol";

// Types and parameters
import { EntityRecordParams, EntityMetadataParams } from "./types.sol";

/**
 * @title EntityRecordSystem
 * @author CCP Games
 * EntityRecordSystem stores in game entity records on chain.
 */
contract EntityRecordSystem is SmartObjectFramework {
  /**
   * @dev creates a new entity record
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param entityRecordParams is the EnityRecordParams struct with all the data needed to create a new entity record
   * @dev access control: this function is only callable directly by the admin role or by the inventory or ephemeral inventory systems
   */
  function createRecord(
    uint256 smartObjectId,
    EntityRecordParams memory entityRecordParams
  ) public context access(smartObjectId) {
    EntityRecord.set(
      smartObjectId,
      true,
      entityRecordParams.tenantId,
      entityRecordParams.typeId,
      entityRecordParams.itemId,
      entityRecordParams.volume
    );
  }

  /**
   * @dev creates the metadata for an entity record
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param entityRecordMetadata is the EntityMetadata struct with all the data needed to create a new entity record metadata
   * @dev access control: this function is only callable by the smart object owner directly or via scoped system call (or in the case of SmartCharacter by the admin role directly or via scoped system call)
   */
  function createMetadata(
    uint256 smartObjectId,
    EntityMetadataParams memory entityRecordMetadata
  ) public context access(smartObjectId) scope(smartObjectId) {
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
   * @dev access control: this function is only callable by the smart object owner directly or via scoped system call (or in the case of SmartCharacter by the admin role directly or via scoped system call)
   */
  function setName(
    uint256 smartObjectId,
    string memory name
  ) public context access(smartObjectId) scope(smartObjectId) {
    EntityRecordMetadata.setName(smartObjectId, name);
  }

  /**
   * @dev sets the dappURL of an entity
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param dappURL the dappURL of the entity
   * @dev access control: this function is callable by the smart object owner (or an admin) directly or via scoped system call
   */
  function setDappURL(
    uint256 smartObjectId,
    string memory dappURL
  ) public context access(smartObjectId) scope(smartObjectId) {
    EntityRecordMetadata.setDappURL(smartObjectId, dappURL);
  }

  /**
   * @dev sets the description of an entity
   * @param smartObjectId the id of a in game entity referred as smart object id
   * @param description the description of the entity
   * @dev access control: this function is callable by the smart object owner (or an admin) directly or via scoped system call
   */
  function setDescription(
    uint256 smartObjectId,
    string memory description
  ) public context access(smartObjectId) scope(smartObjectId) {
    EntityRecordMetadata.setDescription(smartObjectId, description);
  }
}
