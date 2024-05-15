// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { SmartObjectData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { InventoryItem } from "../../inventory/types.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

interface IGateKeeper {
  function createAndAnchorGateKeeper(
    uint256 smartObjectId,
    EntityRecordTableData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) external;

  function ephemeralToInventoryTransferHook(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) external;
}
