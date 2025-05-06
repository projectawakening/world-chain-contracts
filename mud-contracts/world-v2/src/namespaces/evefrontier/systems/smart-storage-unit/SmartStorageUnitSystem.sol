// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Initialize } from "../../codegen/index.sol";

// Local namespace systems
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { smartStorageUnitSystem } from "../../codegen/systems/SmartStorageUnitSystemLib.sol";
// Types and parameters
import { CreateAndAnchorParams } from "../deployable/types.sol";
import { SMART_STORAGE_UNIT } from "../constants.sol";

contract SmartStorageUnitSystem is SmartObjectFramework {
  /**
   * @notice Create and anchor a Smart Storage Unit
   * @param params CreateAndAnchorDeployableParams
   * @param capacity is the capacity of the storage unit
   * @param ephemeralCapacity is the ephemeral capacity of the storage unit
   * @param networkNodeId is the id of the network node this storage unit is connected to
   */
  function createAndAnchorStorageUnit(
    CreateAndAnchorParams memory params,
    uint256 capacity,
    uint256 ephemeralCapacity,
    uint256 networkNodeId
  ) public context access(params.smartObjectId) scope(getSmartStorageUnitClassId()) {
    params.assemblyType = SMART_STORAGE_UNIT;

    entitySystem.instantiate(getSmartStorageUnitClassId(), params.smartObjectId, params.owner);

    deployableSystem.createAndAnchor(params, networkNodeId);

    inventorySystem.setCapacity(params.smartObjectId, capacity);

    inventorySystem.setEphemeralCapacity(params.smartObjectId, ephemeralCapacity);
  }

  function getSmartStorageUnitClassId() public view returns (uint256) {
    return Initialize.get(smartStorageUnitSystem.toResourceId());
  }
}
