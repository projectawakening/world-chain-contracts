// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EntityRecordData, SmartObjectData, WorldPosition } from "../types.sol";
import { InventoryItem } from "../../inventory/types.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

interface ISmartStorageUnit {
  function createAndAnchorSmartStorageUnit(
    uint256 smartStorageUnitId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) external;

  function createAndDepositItemsToInventory(uint256 smartObjectId, InventoryItem[] memory items) external;

  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) external;

  function setDeployableMetadata(
    uint256 smartObjectId,
    string memory name,
    string memory dappURL,
    string memory description
  ) external;

  function setSSUClassId(uint256 classId) external;
}
