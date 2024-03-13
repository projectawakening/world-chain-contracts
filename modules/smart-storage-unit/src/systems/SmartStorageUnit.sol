// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, InventoryItem } from "./types.sol";

contract SmartStorageUnit is System {
  function createAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
  }

  function bringOnline(uint256 smartObjectId) public {
    //Implement the logic to bring the smart storage unit online
  }

  function bringOffline(uint256 smartObjectId) public {
    //Implement the logic to bring the smart storage unit offline
  }

  function unanchor(uint256 smartObjectId) public {
    //Implement the logic to unanchor the smart storage unit
    // Scoop all items from the inventory
  }

  function destroy(uint256 smartObjectId) public {
    //Implement the logic to destroy the smart storage unit
    // Scoop all items from the inventory
  }

  function offlineAll() public {
    //Implement the logic to bring all smart storage units offline
  }

  function depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to deposit items to the inventory
  }

  function depositToEphemeralInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to deposit items to the inventory
  }

  function withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to withdraw items from the inventory
  }

  function withdrawFromEphemeralInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to withdraw items from the inventory
  }
}
