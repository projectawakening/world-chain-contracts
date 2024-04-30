// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EntityRecordData, SmartObjectData, WorldPosition, InventoryItem } from "../types.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

interface ISmartStorageUnit {
  function createAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) external;

  function createAndDepositItemsToInventory(uint256 smartObjectId, InventoryItem[] memory items) external;

  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) external;

  function setDeploybaleMetadata(
    uint256 smartObjectId,
    string memory name,
    string memory dappURL,
    string memory description
  ) external;
}
