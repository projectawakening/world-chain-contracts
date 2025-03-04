// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Core MUD/Lattice imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Type definitions
import { State, SmartObjectData } from "../deployable/types.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { CreateAndAnchorDeployableParams } from "../deployable/types.sol";
import { State as CommonState } from "../../../../codegen/common.sol";

// Constants
import { DECIMALS, ONE_UNIT_IN_WEI } from "./../constants.sol";

// Table/codegen imports
import { Anchor, AnchorData, AnchoredTo, DeployableState } from "../../codegen/index.sol";

// System imports
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";
import { smartAssemblySystem } from "../../codegen/systems/SmartAssemblySystemLib.sol";
import { locationSystem } from "../../codegen/systems/LocationSystemLib.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

// Local system imports
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { FuelSystem } from "../fuel/FuelSystem.sol";

/**
 * @title AnchorSystem
 */
contract AnchorSystem is SmartObjectFramework {
  error AnchorSystem_AnchorNotFound(uint256 anchorId);
  error AnchorSystem_AnchorAlreadyExists(uint256 anchorId);
  error AnchorSystem_DeployableNotFound(uint256 deployableId);
  error AnchorSystem_DeployableNotAnchored(uint256 deployableId, uint256 anchorId);
  function createAnchor(uint256 smartObjectId) public context access(smartObjectId) {
    if (Anchor.getCreatedAt(smartObjectId) != 0) revert AnchorSystem_AnchorAlreadyExists(smartObjectId);

    Anchor.set(smartObjectId, AnchorData({ anchoredObjects: new uint256[](0), createdAt: block.timestamp }));
  }

  function anchorDeployable(uint256 anchorId, uint256 deployableId) public context access(anchorId) {
    if (Anchor.getCreatedAt(anchorId) == 0) revert AnchorSystem_AnchorNotFound(anchorId);

    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    uint256[] memory newAnchoredObjects = new uint256[](anchoredObjects.length + 1);

    if (DeployableState.getCreatedAt(deployableId) == 0) revert AnchorSystem_DeployableNotFound(deployableId);

    for (uint256 i = 0; i < anchoredObjects.length; i++) {
      newAnchoredObjects[i] = anchoredObjects[i];
    }
    newAnchoredObjects[anchoredObjects.length] = deployableId;

    Anchor.setAnchoredObjects(anchorId, newAnchoredObjects);
    AnchoredTo.set(deployableId, anchorId, block.timestamp);
  }

  function unanchorDeployable(uint256 anchorId, uint256 deployableId) public context access(anchorId) {
    if (Anchor.getCreatedAt(anchorId) == 0) revert AnchorSystem_AnchorNotFound(anchorId);
    if (AnchoredTo.getAnchoredAt(deployableId, anchorId) == 0)
      revert AnchorSystem_DeployableNotAnchored(deployableId, anchorId);

    uint256[] memory anchoredObjects = Anchor.getAnchoredObjects(anchorId);
    for (uint256 i = 0; i < anchoredObjects.length; i++) {
      if (anchoredObjects[i] == deployableId) {
        anchoredObjects[i] = anchoredObjects[anchoredObjects.length - 1];
        anchoredObjects[anchoredObjects.length - 1] = 0;
        break;
      }
    }
    uint256[] memory newAnchoredObjects = new uint256[](anchoredObjects.length - 1);
    for (uint256 i = 0; i < newAnchoredObjects.length; i++) {
      newAnchoredObjects[i] = anchoredObjects[i];
    }

    Anchor.setAnchoredObjects(anchorId, anchoredObjects);
    AnchoredTo.set(deployableId, 0, 0);
  }
}
