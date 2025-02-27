// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { LocationData } from "../../codegen/index.sol";
import { DeployableSystemLib, deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { InventorySystemLib, inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystemLib, ephemeralInventorySystem } from "../../codegen/systems/EphemeralInventorySystemLib.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { SmartObjectData } from "../deployable/types.sol";
import { WorldPosition } from "../location/types.sol";
import { SMART_STORAGE_UNIT } from "../constants.sol";
import { CreateAndAnchorDeployableParams } from "../deployable/types.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

contract SmartStorageUnitSystem is SmartObjectFramework {
  function createAndAnchorSmartStorageUnit(
    CreateAndAnchorDeployableParams memory params,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public context access(params.smartObjectId) scope(getSmartStorageUnitClassId()) {
    entitySystem.instantiate(getSmartStorageUnitClassId(), params.smartObjectId, params.owner);

    params.smartAssemblyType = SMART_STORAGE_UNIT;
    deployableSystem.createAndAnchorDeployable(params);

    inventorySystem.setInventoryCapacity(params.smartObjectId, storageCapacity);

    ephemeralInventorySystem.setEphemeralInventoryCapacity(params.smartObjectId, ephemeralStorageCapacity);
  }

  function getSmartStorageUnitClassId() public pure returns (uint256) {
    return uint256(bytes32("SSU"));
  }
}
