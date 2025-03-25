//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Characters, CharactersByAccount, EntityRecord, Initialize, Tenant } from "../../codegen/index.sol";

// Local namespace systems
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { smartCharacterSystem } from "../../codegen/systems/SmartCharacterSystemLib.sol";

// Types and parameters
import { EntityRecordParams, EntityMetadataParams } from "../entity-record/types.sol";

contract SmartCharacterSystem is SmartObjectFramework {
  error SmartCharacter_AlreadyCreated(address account, uint256 smartObjectId);
  error SmartCharacterDoesNotExist(uint256 smartObjectId);
  error SmartCharacter_InvalidTenantId(uint256 smartObjectId, bytes32 tenantId);
  error SmartCharacter_InvalidTypeId(uint256 smartObjectId, uint256 typeId);
  error SmartCharacter_InvalidObjectId(uint256 smartObjectId);
  /**
   * @notice Create a new character
   * @param smartObjectId The ID of the character smart object
   * @param owner The owning account of the character
   * @param tribeId The tribe ID of the character
   * @param entityRecordParams The entity record params
   * @param entityRecordMetadata The entity record metadata
   */
  function createCharacter(
    uint256 smartObjectId,
    address owner,
    uint256 tribeId,
    EntityRecordParams memory entityRecordParams,
    EntityMetadataParams memory entityRecordMetadata
  ) public context access(smartObjectId) scope(getSmartCharacterClassId()) {
    uint256 createdAt = block.timestamp;

    // enforce one-to-one mapping between an account and a character
    // TODO: move this logic to character class hook enforcement
    if (CharactersByAccount.getSmartObjectId(owner) != 0) {
      revert SmartCharacter_AlreadyCreated(owner, smartObjectId);
    }

    // sanity checks
    if (Tenant.get() != entityRecordParams.tenantId) {
      revert SmartCharacter_InvalidTenantId(smartObjectId, entityRecordParams.tenantId);
    }
    if (
      uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.typeId))) !=
      getSmartCharacterClassId()
    ) {
      revert SmartCharacter_InvalidTypeId(smartObjectId, entityRecordParams.typeId);
    }
    if (smartObjectId != uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.itemId)))) {
      revert SmartCharacter_InvalidObjectId(smartObjectId);
    }

    // Instantiate the character object
    entitySystem.instantiate(getSmartCharacterClassId(), smartObjectId, owner);
    // Save the entity record in EntityRecord Table
    entityRecordSystem.createRecord(smartObjectId, entityRecordParams);
    entityRecordSystem.createMetadata(smartObjectId, entityRecordMetadata);
    // Save the character data in Characters Table
    Characters.set(smartObjectId, true, tribeId, createdAt);
    // assign the character ownership data - using the singleton version
    ownershipSystem.assignOwner(smartObjectId, owner);
    // Save the character reverse lookup in the CharactersByAccount Table
    CharactersByAccount.set(owner, smartObjectId);
  }

  function updateTribeId(
    uint256 smartObjectId,
    uint256 tribeId
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (Characters.getTribeId(smartObjectId) == 0) {
      revert SmartCharacterDoesNotExist(smartObjectId);
    }
    Characters.setTribeId(smartObjectId, tribeId);
  }

  function removeCharacter(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    if (!Characters.getExists(smartObjectId)) {
      revert SmartCharacterDoesNotExist(smartObjectId);
    }

    // Get the current owner before we delete records
    address owner = ownershipSystem.owner(smartObjectId);

    // Delete the character reverse lookup in the CharactersByAccount Table
    CharactersByAccount.deleteRecord(owner);

    // remove the character ownership data using the singleton version
    ownershipSystem.removeOwner(smartObjectId, owner);

    // Delete the character data in Characters Table
    Characters.deleteRecord(smartObjectId);

    // Delete the character object
    entitySystem.deleteObject(smartObjectId);
  }

  function getSmartCharacterClassId() public view returns (uint256) {
    return Initialize.get(smartCharacterSystem.toResourceId());
  }
}
