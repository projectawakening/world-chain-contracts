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
  function createAndAnchorStorageUnit(
    CreateAndAnchorParams memory params,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public context access(params.smartObjectId) scope(getSmartStorageUnitClassId()) {
    entitySystem.instantiate(getSmartStorageUnitClassId(), params.smartObjectId, params.owner);

    params.assemblyType = SMART_STORAGE_UNIT;
    deployableSystem.createAndAnchor(params);

    inventorySystem.setCapacity(params.smartObjectId, storageCapacity);

    inventorySystem.setEphemeralCapacity(params.smartObjectId, ephemeralStorageCapacity);
  }

  function getSmartStorageUnitClassId() public view returns (uint256) {
    return Initialize.get(smartStorageUnitSystem.toResourceId());
  }
}
