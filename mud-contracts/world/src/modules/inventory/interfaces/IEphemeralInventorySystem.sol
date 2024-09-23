// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { InventoryItem } from "../types.sol";

/**
 * @title IEphemeralInventorySystem
 * @dev This interface is to make interacting with the underlying system easier via world.call.
 */
interface IEphemeralInventorySystem {
  function setEphemeralInventoryCapacity(uint256 smartObjectId, uint256 ephemeralStorageCapacity) external;

  function depositToEphemeralInventory(uint256 smartObjectId, address owner, InventoryItem[] memory items) external;

  function withdrawFromEphemeralInventory(uint256 smartObjectId, address owner, InventoryItem[] memory items) external;
}
