// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { SMART_STORAGE_MODULE_NAME, SMART_STORAGE_MODULE_NAMESPACE } from "./constants.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, InventoryItem } from "../types.sol";

import { EntityRecordLib } from "../entity-record/EntityRecordLib.sol";

contract SmartStorageUnit is System {
  using WorldResourceIdInstance for ResourceId;

  /**
   * @notice Create and anchor a smart storage unit
   * @dev Create and anchor a smart storage unit by smart object id
   * @param smartObjectId The smart object id
   * @param entityRecordData The entity record data of the smart object
   * @param smartObjectData is the token metadata of the smart object
   * @param worldPosition The position of the smart object in the game
   * @param storageCapacity The storage capacity of the smart storage unit
   * @param ephemeralStorageCapacity The personal storage capacity of the smart storage unit
   */
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

  /**
   * @notice Create an item on chain and deposit it to the inventory
   * @dev Create an item by smart object id
   * //TODO only server account can create items on-chain
   * //TODO Represent item as a ERC1155 asset with ownership on-chain
   * @param smartObjectId The smart object id
   * @param item The item to create
   */
  function createAndDepositItemsToInventory(uint256 smartObjectId, InventoryItem memory item) public {
    //Check if the item exists on-chain if not Create entityRecord
    //Deposit item to the inventory
  }

  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address inventoryOwner,
    InventoryItem[] memory items
  ) public {
    //Check if the item exists on-chain if not Create entityRecord
    //Deposit item to the ephemeral inventory
  }

  function smartStorageUnitSystemId() public pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: SMART_STORAGE_MODULE_NAMESPACE,
        name: SMART_STORAGE_MODULE_NAME
      });
  }
}
