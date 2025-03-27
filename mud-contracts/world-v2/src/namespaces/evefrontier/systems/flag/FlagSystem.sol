// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Core MUD/Lattice imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Type definitions
import { State } from "../deployable/types.sol";
import { EntityRecordParams } from "../entity-record/types.sol";
import { CreateAndAnchorParams } from "../deployable/types.sol";
import { State as CommonState } from "../../../../codegen/common.sol";

// Constants
import { FLAG } from "../constants.sol";

// Table/codegen imports
import { Initialize } from "../../codegen/index.sol";

// System imports
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";
import { locationSystem } from "../../codegen/systems/LocationSystemLib.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";
import { anchorSystem } from "../../codegen/systems/AnchorSystemLib.sol";
import { flagSystem } from "../../codegen/systems/FlagSystemLib.sol";

/**
 * @title FlagSystem
 * @author Eve World
 * @notice System for managing Flag deployables which serve as anchors with fuel
 */
contract FlagSystem is SmartObjectFramework {
  /**
   * @notice Creates and anchors a new Flag
   * @param params Parameters for creating the deployable
   */
  function createFlag(
    CreateAndAnchorParams memory params
  ) public context access(params.smartObjectId) scope(getFlagClassId()) {
    // Instantiate the entity with the Flag class
    entitySystem.instantiate(getFlagClassId(), params.smartObjectId, params.owner);

    // Set the smart assembly type to FLAG
    params.assemblyType = FLAG;

    // Must set Anchor attributes before deploying
    // Deployment checks if we are an Anchor
    anchorSystem.createAnchor(params.smartObjectId);
    
    deployableSystem.createAndAnchor(params);
  }

  /**
   * @notice Gets the class ID for the Flag system
   * @return The class ID
   */
  function getFlagClassId() public view returns (uint256) {
    return Initialize.get(flagSystem.toResourceId());
  }
}
