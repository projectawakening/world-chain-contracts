// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

// Local namespace tables
import { ItemTransfer } from "../../codegen/tables/ItemTransfer.sol";

// Local namespace systems
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { ephemeralInventorySystem } from "../../codegen/systems/EphemeralInventorySystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";

// Types and parameters
import { InventoryItemParams } from "./types.sol";

/**
 * @title EphemeralInteractSystem
 * @author CCP Games
 * @notice This system provides builder functionality for the interaction between ephemeral inventories and a smart object's primary inventory
 */

contract EphemeralInteractSystem is SmartObjectFramework {
  /**
   * @notice Transfer items from an ephemeral inventory to the smart object's inventory
   * @param smartObjectId is the smart object id
   * @param ephemeralOwner is the ephemeral inventory owner
   * @param items is the array of items to transfer
   */
  function transferFromEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    address inventoryOwner = ownershipSystem.owner(smartObjectId);

    // withdraw the items from the designated ephemeral inventory
    ephemeralInventorySystem.withdraw(smartObjectId, ephemeralOwner, items);
    // deposit the items to the designated inventory
    inventorySystem.deposit(smartObjectId, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      ItemTransfer.set(smartObjectId, items[i].smartObjectId, ephemeralOwner, inventoryOwner, items[i].quantity, block.timestamp);
    }
  }

  /**
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory storage to an ephemeral storage
   * @param smartObjectId is the smart object id
   * @param ephemeralOwner is the ephemeral inventory owner
   * @param items is the array of items to transfer
   */
  function transferToEphemeral(
    uint256 smartObjectId,
    address ephemeralOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) scope(smartObjectId) {
    address inventoryOwner = ownershipSystem.owner(smartObjectId);

    // withdraw the items from the designated inventory
    inventorySystem.withdraw(smartObjectId, items);
    // deposit the items to the designated ephemeral inventory
    ephemeralInventorySystem.deposit(smartObjectId, ephemeralOwner, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      ItemTransfer.set(smartObjectId, items[i].smartObjectId, inventoryOwner, ephemeralOwner, items[i].quantity, block.timestamp);
    }
  }

  function setTransferFromEphemeralAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) scope(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_FROM_EPHEMERAL_ROLE", smartObjectId));

    if (isAllowed) {
      roleManagementSystem.grantRole(accessRole, accessAddress);
    } else {
      roleManagementSystem.revokeRole(accessRole, accessAddress);
    }
  }

  function setTransferToEphemeralAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) scope(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_TO_EPHEMERAL_ROLE", smartObjectId));

    if (isAllowed) {
      roleManagementSystem.grantRole(accessRole, accessAddress);
    } else {
      roleManagementSystem.revokeRole(accessRole, accessAddress);
    }
  }
}
