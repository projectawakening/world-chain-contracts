// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { HasRole, Role } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

// Local namespace tables
import { EphemeralItemTransfer } from "../../codegen/tables/EphemeralItemTransfer.sol";

// Local namespace systems
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { ephemeralInventorySystem } from "../../codegen/systems/EphemeralInventorySystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";

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
  ) public context access(smartObjectId) {
    bytes memory returnData = IWorldWithContext(_world()).callStatic(
      ownershipSystem.toResourceId(),
      abi.encodeCall(OwnershipSystem.owner, (smartObjectId))
    );
    address inventoryOwner = abi.decode(returnData, (address));

    // withdraw the items from the designated ephemeral inventory
    ephemeralInventorySystem.withdrawEphemeral(smartObjectId, ephemeralOwner, items);
    // deposit the items to the designated inventory
    inventorySystem.depositInventory(smartObjectId, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      EphemeralItemTransfer.set(
        smartObjectId,
        items[i].smartObjectId,
        ephemeralOwner,
        inventoryOwner,
        items[i].quantity,
        block.timestamp
      );
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
  ) public context access(smartObjectId) {
    bytes memory returnData = IWorldWithContext(_world()).callStatic(
      ownershipSystem.toResourceId(),
      abi.encodeCall(OwnershipSystem.owner, (smartObjectId))
    );
    address inventoryOwner = abi.decode(returnData, (address));

    // withdraw the items from the designated inventory
    inventorySystem.withdrawInventory(smartObjectId, items);
    // deposit the items to the designated ephemeral inventory
    ephemeralInventorySystem.depositEphemeral(smartObjectId, ephemeralOwner, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      EphemeralItemTransfer.set(
        smartObjectId,
        items[i].smartObjectId,
        inventoryOwner,
        ephemeralOwner,
        items[i].quantity,
        block.timestamp
      );
    }
  }

  /**
   * @notice Transfer items from one ephemeral inventory to another
   * @param smartObjectId is the smart object id
   * @param fromEphemeralOwner is the source ephemeral inventory owner
   * @param toEphemeralOwner is the destination ephemeral inventory owner
   * @param items is the array of items to transfer
   * NOTE: in addition to any configured access restrictions, the _callMsgSender(1) must be equal to `fromEphemeralOwner` for safe operations
   */
  function crossTransferToEphemeral(
    uint256 smartObjectId,
    address fromEphemeralOwner,
    address toEphemeralOwner,
    InventoryItemParams[] memory items
  ) public context access(smartObjectId) {
    // withdraw the items from the designated inventory
    ephemeralInventorySystem.withdrawEphemeral(smartObjectId, fromEphemeralOwner, items);
    // deposit the items to the designated ephemeral inventory
    ephemeralInventorySystem.depositEphemeral(smartObjectId, toEphemeralOwner, items);

    // record each item transfer
    for (uint i = 0; i < items.length; i++) {
      EphemeralItemTransfer.set(
        smartObjectId,
        items[i].smartObjectId,
        fromEphemeralOwner,
        toEphemeralOwner,
        items[i].quantity,
        block.timestamp
      );
    }
  }

  function setTransferFromEphemeralAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_FROM_EPHEMERAL_ROLE", smartObjectId));

    // Create the role if it doesn't exist
    if (!Role.getExists(accessRole)) {
      roleManagementSystem.scopedCreateRole(smartObjectId, accessRole, accessRole, accessAddress);
    }

    // Grant or revoke the role
    if (!HasRole.getIsMember(accessRole, accessAddress) && isAllowed) {
      roleManagementSystem.scopedGrantRole(smartObjectId, accessRole, accessAddress);
    } else if (HasRole.getIsMember(accessRole, accessAddress) && !isAllowed) {
      roleManagementSystem.scopedRevokeRole(smartObjectId, accessRole, accessAddress);
    }
  }

  function setTransferToEphemeralAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("TRANSFER_TO_EPHEMERAL_ROLE", smartObjectId));

    // Create the role if it doesn't exist
    if (!Role.getExists(accessRole)) {
      roleManagementSystem.scopedCreateRole(smartObjectId, accessRole, accessRole, accessAddress);
    }

    // Grant or revoke the role
    if (!HasRole.getIsMember(accessRole, accessAddress) && isAllowed) {
      roleManagementSystem.scopedGrantRole(smartObjectId, accessRole, accessAddress);
    } else if (HasRole.getIsMember(accessRole, accessAddress) && !isAllowed) {
      roleManagementSystem.scopedRevokeRole(smartObjectId, accessRole, accessAddress);
    }
  }

  function setCrossTransferToEphemeralAccess(
    uint256 smartObjectId,
    address accessAddress,
    bool isAllowed
  ) public context access(smartObjectId) {
    bytes32 accessRole = keccak256(abi.encodePacked("CROSS_TRANSFER_TO_EPHEMERAL_ROLE", smartObjectId));

    // Create the role if it doesn't exist
    if (!Role.getExists(accessRole)) {
      roleManagementSystem.scopedCreateRole(smartObjectId, accessRole, accessRole, accessAddress);
    }

    // Grant or revoke the role
    if (!HasRole.getIsMember(accessRole, accessAddress) && isAllowed) {
      roleManagementSystem.scopedGrantRole(smartObjectId, accessRole, accessAddress);
    } else if (HasRole.getIsMember(accessRole, accessAddress) && !isAllowed) {
      roleManagementSystem.scopedRevokeRole(smartObjectId, accessRole, accessAddress);
    }
  }
}
