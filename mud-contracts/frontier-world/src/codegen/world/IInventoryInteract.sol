// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { InventoryItem } from "./../../modules/inventory/types.sol";

/**
 * @title IInventoryInteract
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IInventoryInteract {
  function eveworld__inventoryToEphemeralTransfer(uint256 smartObjectId, InventoryItem[] memory items) external;

  function eveworld__ephemeralToInventoryTransfer(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) external;

  function eveworld__configureInteractionHandler(uint256 smartObjectId, bytes memory interactionParams) external;
}
