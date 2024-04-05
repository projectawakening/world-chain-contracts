// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { InventoryTable } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { InventoryItem } from "../../types.sol";
import { Utils } from "../Utils.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";

contract InventorySystem is EveSystem {
  using Utils for bytes14;

  /**
   * @notice Set the inventory capacity
   * @dev Set the inventory capacity by smart storage unit id
   * @param smartObjectId The smart storage unit id
   * @param storageCapacity The storage capacity
   */
  function setInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    if (storageCapacity == 0) {
      revert IInventoryErrors.Inventory_InvalidCapacity("InventorySystem: storage capacity cannot be 0");
    }
    InventoryTable.setCapacity(_namespace().inventoryTableId(), smartObjectId, storageCapacity);
  }

  /**
   * @notice Deposit items to the inventory
   * @dev Deposit items to the inventory by smart storage unit id
   * //TODO Only owner of the smart storage unit can deposit items in the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to deposit to the inventory
   */
  function depositToInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    for (uint256 i = 0; i < items.length; i++) {
      InventoryItem memory item = items[i];
      InventoryTable.pushItems(_namespace().inventoryTableId(), smartObjectId, item.inventoryItemId);
      InventoryItemTable.set(
        _namespace().inventoryItemTableId(),
        smartObjectId,
        item.inventoryItemId,
        item.quantity,
        i
      );
    }
  }

  /**
   * @notice Withdraw items from the inventory
   * @dev Withdraw items from the inventory by smart storage unit id
   * //TODO Only owner of the smart storage unit can withdraw items from the inventory
   * @param smartObjectId The smart storage unit id
   * @param items The items to withdraw from the inventory
   */
  function withdrawFromInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to withdraw items from the inventory
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().inventorySystemId();
  }
}
