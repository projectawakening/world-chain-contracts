// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

// Local namespace tables
import { ObjectItemTransfer } from "../../codegen/tables/ObjectItemTransfer.sol";

// Local namespace systems
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";

// Types and parameters
import { InventoryItemParams } from "./types.sol";

/**
 * @title InventoryInteractSystem
 * @author CCP Games
 * @notice This system provides builder functionality for the interaction between a smart object's primary inventory and an ephemeral inventory
 */

contract InventoryInteractSystem is SmartObjectFramework {
  /**
   * @notice Transfer items to another primary inventory
   * @param smartObjectId is the associated smart object id of the inventory to transfer from
   * @param toObjectId is the associated smart object id of the inventory to transfer to
   * @param items is the array of items to transfer
   */
  function transferToInventory(
    uint256 smartObjectId,
    uint256 toObjectId,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    address inventoryOwner = ownershipSystem.owner(smartObjectId);
    address toInventoryOwner = ownershipSystem.owner(toObjectId);

    // withdraw the items from the designated inventory
    inventorySystem.withdraw(smartObjectId, items);
    // deposit the items to the designated inventory
    inventorySystem.deposit(toObjectId, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      ObjectItemTransfer.set(smartObjectId, items[i].smartObjectId, toObjectId, inventoryOwner, toInventoryOwner, items[i].quantity, block.timestamp);
    }
  }

  function setTransferToInventoryAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) scope(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_TO_INVENTORY_ROLE", smartObjectId));

    if (isAllowed) {
      roleManagementSystem.grantRole(accessRole, accessAddress);
    } else {
      roleManagementSystem.revokeRole(accessRole, accessAddress);
    }
  }
}