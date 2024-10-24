// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { SmartAssemblyData, SmartAssembly } from "../../codegen/index.sol";
import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { EntityRecordSystem } from "../entity-record/EntityRecordSystem.sol";

import { DEPLOYMENT_NAMESPACE } from "./../constants.sol";
import { EveSystem } from "../EveSystem.sol";

/**
 * @title SmartAssemblySystem
 * @author CCP Games
 * @notice This is the base building block for all smart objects
 */
contract SmartAssemblySystem is EveSystem {
  error SmartAssemblyTypeAlreadyExists(uint256 smartObjectId);
  error SmartAssemblyTypeCannotBeEmpty(uint256 smartObjectId);
  error SmartAssemblyDoesNotExist(uint256 smartObjectId);

  ResourceId entityRecordUtils = EntityRecordUtils.entityRecordSystemId();

  /**
   * @notice Create a new smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param smartAssemblyType The type of the smart assembly
   * @param entityRecord The entity record data
   * //TODO : only owner can create smart assembly
   */
  function createSmartAssembly(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    EntityRecordData memory entityRecord
  ) public {
    world().call(
      entityRecordUtils,
      abi.encodeCall(EntityRecordSystem.createEntityRecord, (smartObjectId, entityRecord))
    );
    setSmartAssemblyType(smartObjectId, smartAssemblyType);
  }

  /**
   * @notice Set the type of the smart assembly
   * @param smartObjectId The ID of the smart assembly
   * @param smartAssemblyType The type of the smart assembly
   * //TODO : only owner can set smart assembly type
   */
  function setSmartAssemblyType(uint256 smartObjectId, string memory smartAssemblyType) public {
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
  function updateSmartAssemblyType(uint256 smartObjectId, string memory smartAssemblyType) public {
    if (
      keccak256(abi.encodePacked(SmartAssembly.getSmartAssemblyType(smartObjectId))) == keccak256(abi.encodePacked(""))
    ) {
      revert SmartAssemblyDoesNotExist(smartObjectId);
    }
    uint256 smartAssemblyEnumId = SmartAssembly.getSmartAssemblyId(smartObjectId);
    SmartAssembly.set(smartObjectId, smartAssemblyEnumId, smartAssemblyType);
  }
}
