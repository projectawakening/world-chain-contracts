// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { TransferItem } from "../types.sol";

/**
 * @title IInventoryInteractSystem
 * @dev This interface is to make interacting with the underlying system easier via world.call.
 */
interface IInventoryInteractSystem {
  function inventoryToEphemeralTransfer(
    uint256 smartObjectId,
    address ephemeralInvOwner,
    TransferItem[] memory items
  ) external;

  function ephemeralToInventoryTransfer(uint256 smartObjectId, TransferItem[] memory items) external;

  // Object Inventory Owner InventoryInteract function access control
  function setApprovedAccessList(uint256 smartObjectId, address[] memory accessList) external;

  function setAllInventoryTransferAccess(uint256 smartObjectId, bool isEnforced) external;

  function setEphemeralToInventoryTransferAccess(uint256 smartObjectId, bool isEnforced) external;

  function setInventoryToEphemeralTransferAccess(uint256 smartObjectId, bool isEnforced) external;
}
