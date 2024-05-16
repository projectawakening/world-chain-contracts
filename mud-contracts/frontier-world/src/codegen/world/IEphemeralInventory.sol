// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { InventoryItem } from "./../../modules/inventory/types.sol";

/**
 * @title IEphemeralInventory
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IEphemeralInventory {
  function eveworld__setEphemeralInventoryCapacity(uint256 smartObjectId, uint256 ephemeralStorageCapacity) external;

  function eveworld__depositToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) external;

  function eveworld__withdrawFromEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) external;
}
