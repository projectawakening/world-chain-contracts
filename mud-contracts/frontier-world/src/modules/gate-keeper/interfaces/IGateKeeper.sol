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

  function setAcceptedItemTypeId(uint256 smartObjectId, uint256 entityTypeId) external;

  function setTargetQuantity(uint256 smartObjectId, uint256 targetItemQuantity) external;

  function ephemeralToInventoryTransferHook(
    bytes memory hookArgs
  ) external;

  function depositToInventoryHook(
   // bytes memory hookArgs
       uint256 smartObjectId,
    InventoryItem[] memory items
  ) external;
}
