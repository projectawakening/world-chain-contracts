// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { EntityRelationValue, TAG_TYPE_ENTITY_RELATION } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { EntityTagMap } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { SmartAssembly, Tenant } from "../../codegen/index.sol";

// Local namespace systems
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

// Types and parameters
import { EntityRecordParams } from "../entity-record/types.sol";
import { DEPLOYMENT_NAMESPACE } from "../constants.sol";

/**
 * @title SmartAssemblySystem
 * @author CCP Games
 * @notice This is the base building block for all smart objects
 */
contract SmartAssemblySystem is SmartObjectFramework {
  error SmartAssembly_TypeCannotBeEmpty(uint256 smartObjectId);
  error SmartAssembly_DoesNotExist(uint256 smartObjectId);
  error SmartAssembly_InvalidTypeId(uint256 smartObjectId, uint256 typeId);
  error SmartAssembly_InvalidTenantId(uint256 smartObjectId, bytes32 tenantId);
  error SmartAssembly_InvalidObjectId(uint256 smartObjectId);

  /**
   * @notice Create a new smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param assemblyType The type of the smart assembly
   * @param entityRecordParams The entity record data
   */
  function create(
    uint256 smartObjectId,
    string memory assemblyType,
    EntityRecordParams memory entityRecordParams
  ) public context access(smartObjectId) scope(smartObjectId) {
    // get this assembly's designated classId
    EntityRelationValue memory entityRelationValue = abi.decode(
      EntityTagMap.getValue(smartObjectId, TagIdLib.encode(TAG_TYPE_ENTITY_RELATION, bytes30(bytes32(smartObjectId)))),
      (EntityRelationValue)
    );
    // sanity checks
    if (uint256(keccak256(abi.encodePacked(entityRecordParams.typeId))) != entityRelationValue.relatedEntityId) {
      revert SmartAssembly_InvalidTypeId(smartObjectId, entityRecordParams.typeId);
    }
    if (Tenant.get() != entityRecordParams.tenantId) {
      revert SmartAssembly_InvalidTenantId(smartObjectId, entityRecordParams.tenantId);
    }
    if (smartObjectId!= uint256(keccak256(abi.encodePacked(entityRecordParams.tenantId, entityRecordParams.itemId)))) {
      revert SmartAssembly_InvalidObjectId(smartObjectId);
    }
    entityRecordSystem.create(smartObjectId, entityRecordParams);
    setType(smartObjectId, assemblyType);
  }

  /**
   * @notice Set the type of the smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param assemblyType The type of the smart assembly
   * //TODO : only owner can set smart assembly type
   */
  function setType(
    uint256 smartObjectId,
    string memory assemblyType
  ) public context access(smartObjectId) scope(smartObjectId) {
    if ((keccak256(abi.encodePacked(assemblyType)) == keccak256(abi.encodePacked("")))) {
      revert SmartAssembly_TypeCannotBeEmpty(smartObjectId);
    }

    uint256 assemblyEnumId = SmartAssembly.getAssemblyId(smartObjectId);
    assemblyEnumId = assemblyEnumId + 1;

    if (
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))) == keccak256(abi.encodePacked(""))
    ) {
      SmartAssembly.set(smartObjectId, assemblyEnumId, assemblyType);
    }
  }

  /**
   * @notice Update the type of the smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param assemblyType The type of the smart assembly
   * //TODO : only owner can update smart assembly type
   */
  function updateType(
    uint256 smartObjectId,
    string memory assemblyType
  ) public context access(smartObjectId) scope(smartObjectId) {
    if (
      keccak256(abi.encodePacked(SmartAssembly.getAssemblyType(smartObjectId))) == keccak256(abi.encodePacked(""))
    ) {
      revert SmartAssembly_DoesNotExist(smartObjectId);
    }
    uint256 assemblyEnumId = SmartAssembly.getAssemblyId(smartObjectId);
    SmartAssembly.set(smartObjectId, assemblyEnumId, assemblyType);
  }
}
