// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { Utils } from "../Utils.sol";
import { InventoryItem } from "../types.sol";

contract InventoryInteract is EveSystem {
  using Utils for bytes14;

  /**
   * @notice Transfer items from inventory to ephemeral
   * @dev transfer items from inventory to ephemeral
   * @param smartObjectId is the smart object id
   * @param items is the array of items to transfer
   */
  function inventoryToEphemeralTransfer(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public hookable(smartObjectId, _systemId()) {
    //withdraw the items from inventory and deposit to ephemeral table
    //get the owner of the ssu and check if he has enough items to transfer to ephemeral
    //transfer the items to ephemeral owner who is the caller of this function
  }

  /**
   * @notice Transfer items from ephemeral to inventory
   * @dev transfer items from ephemeral to inventory
   * @param smartObjectId is the smart object id
   */
  function ephemeralToInventoryTransfer(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public hookable(smartObjectId, _systemId()) {
    //withdraw the items from ephemeral and deposit to inventory table
    //check the caller of this function has enough items to transfer to the inventory
    //transfer items to the ssu owner
  }

  function configureInteractionHandler(
    uint256 smartObjectId,
    bytes memory interactionParams
  ) public hookable(smartObjectId, _systemId()) {
    //configure the interaction handler
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().ephemeralInventorySystemId();
  }
}
