//SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

import { Characters, CharacterToken } from "../../codegen/index.sol";
import { CharactersByAddress } from "../../codegen/tables/CharactersByAddress.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordParams, EntityMetadata } from "../entity-record/types.sol";

import { EntityRecord } from "../../codegen/tables/EntityRecord.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

contract SmartCharacterSystem is SmartObjectFramework {
  error SmartCharacter_AlreadyCreated(address characterAddress, uint256 characterId);
  error SmartCharacterDoesNotExist(uint256 characterId);

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
    EntityMetadata memory entityRecordMetadata
  ) public context access(smartObjectId) scope(getSmartCharacterClassId()) {
    uint256 createdAt = block.timestamp;

    // enforce one-to-one mapping between an account and a character
    // TODO: move this logic to character class hook enforcement
    if (CharactersByAddress.getSmartObjectId(owner) != 0) {
      revert SmartCharacter_AlreadyCreated(owner, smartObjectId);
    }

    // sanity checks
    if (!Tenants.getExists(entityRecordParams.tenantId)) {
      revert SmartCharacter_InvalidTenantId(smartObjectId, entityRecordParams.tenantId);
    }
    if (keccak256(abi.encodePacked(entityRecordParams.typeId)) != getSmartCharacterClassId()) {
      revert SmartCharacter_InvalidTypeId(smartObjectId, entityRecordParams.typeId);
    }
    if (smartObjectId!= uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.itemId)))) {
      revert SmartCharacter_InvalidSmartObjectId(smartObjectId);
    }

    entitySystem.instantiate(getSmartCharacterClassId(), smartObjectId, owner);

    bytes32 ownerRole = keccak256(abi.encodePacked("OWNER_ROLE", smartObjectId)); // OWNER_ROLE tracks/manages object ownership
    
    if(!Role.getExists(ownerRole)) { // ownerRole has not been created, create it
      roleManagementSystem.scopedCreateRole(
        getSmartCharacterClassId(),
        ownerRole,
        ownerRole,
        owner,
        true
      );
    } else if(Role.lengthMembers(ownerRole) == 0) { // ownerRole has already been created, but has no members
      if(Role.getAdmin(ownerRole) != ownerRole) { // ownerRole MUST be self-administered to start with
        roleManagementSystem.scopedTransferRoleAdmin(
          getSmartCharacterClassId(),
          ownerRole,
          ownerRole
        );
      }
      roleManagementSystem.scopedGrantRole(
        getSmartCharacterClassId(),
        ownerRole,
        owner
      );
    } else { // previously created ownerRole has members, start fresh
      if(Role.getAdmin(ownerRole) != ownerRole) {
        roleManagementSystem.scopedTransferRoleAdmin(
          getSmartCharacterClassId(),
          ownerRole,
          ownerRole
        );
      }

      roleManagementSystem.scopedRevokeAll(getSmartCharacterClassId(), ownerRole);
      roleManagementSystem.scopedGrantRole(
        getSmartCharacterClassId(),
        ownerRole,
        owner
      );
    }

    Characters.set(smartObjectId, true,tribeId, createdAt);
    CharactersByAddress.set(owner, smartObjectId);

    //Save the entity record in EntityRecord Module
    entityRecordSystem.createEntityRecord(smartObjectId, entityRecordParams);
    entityRecordSystem.createEntityRecordMetadata(smartObjectId, entityRecordMetadata);
  }

  function updateTribeId(uint256 smartObjectId, uint256 tribeId) public context access(smartObjectId) scope(smartObjectId) {
    if (Characters.getTribeId(smartObjectId) == 0) {
      revert SmartCharacterDoesNotExist(smartObjectId);
    }
    Characters.setTribeId(smartObjectId, tribeId);
  }

  function removeCharacter(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    if (Characters.getExists(smartObjectId) == false) {
      revert SmartCharacterDoesNotExist(smartObjectId);
    }
    bytes32 ownerRole = keccak256(abi.encodePacked("OWNER_ROLE", smartObjectId));
    address owner = Role.getMembers(ownerRole)[0];

    roleManagementSystem.scopedRevokeAll(getSmartCharacterClassId(), ownerRole);

    Characters.deleteRecord(smartObjectId);
    CharactersByAddress.deleteRecord(owner);

    entitySystem.deleteObject(smartObjectId);
  }

  function getSmartCharacterClassId() public pure returns (uint256) {
    return uint256(bytes32("SMART_CHARACTER"));
  }
}
