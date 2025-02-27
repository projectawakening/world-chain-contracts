// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

import { SmartAssemblyData, SmartAssembly } from "../../codegen/index.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";
import { EntityRecordSystemLib, entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

import { DEPLOYMENT_NAMESPACE } from "./../constants.sol";

/**
 * @title SmartAssemblySystem
 * @author CCP Games
 * @notice This is the base building block for all smart objects
 */
contract SmartAssemblySystem is SmartObjectFramework {
  error SmartAssemblyTypeAlreadyExists(uint256 smartObjectId);
  error SmartAssemblyTypeCannotBeEmpty(uint256 smartObjectId);
  error SmartAssemblyDoesNotExist(uint256 smartObjectId);

  /**
   * @notice Create a new smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param smartAssemblyType The type of the smart assembly
   * @param entityRecord The entity record data
   */
  function createSmartAssembly(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    EntityRecordData memory entityRecord
  ) public context access(smartObjectId) {
    entityRecordSystem.createEntityRecord(smartObjectId, entityRecord);
    setSmartAssemblyType(smartObjectId, smartAssemblyType);
  }

  /**
   * @notice Set the type of the smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param smartAssemblyType The type of the smart assembly
   * //TODO : only owner can set smart assembly type
   */
  function setSmartAssemblyType(
    uint256 smartObjectId,
    string memory smartAssemblyType
  ) public context access(smartObjectId) {
    if ((keccak256(abi.encodePacked(smartAssemblyType)) == keccak256(abi.encodePacked("")))) {
      revert SmartAssemblyTypeCannotBeEmpty(smartObjectId);
    }

    uint256 smartAssemblyEnumId = SmartAssembly.getSmartAssemblyId(smartObjectId);
    smartAssemblyEnumId = smartAssemblyEnumId + 1;

    if (
      keccak256(abi.encodePacked(SmartAssembly.getSmartAssemblyType(smartObjectId))) == keccak256(abi.encodePacked(""))
    ) {
      SmartAssembly.set(smartObjectId, smartAssemblyEnumId, smartAssemblyType);
    }
  }

  /**
   * @notice Update the type of the smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param smartAssemblyType The type of the smart assembly
   * //TODO : only owner can update smart assembly type
   */
  function updateSmartAssemblyType(
    uint256 smartObjectId,
    string memory smartAssemblyType
  ) public context access(smartObjectId) {
    if (
      keccak256(abi.encodePacked(SmartAssembly.getSmartAssemblyType(smartObjectId))) == keccak256(abi.encodePacked(""))
    ) {
      revert SmartAssemblyDoesNotExist(smartObjectId);
    }
    uint256 smartAssemblyEnumId = SmartAssembly.getSmartAssemblyId(smartObjectId);
    SmartAssembly.set(smartObjectId, smartAssemblyEnumId, smartAssemblyType);
  }
}
