// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { DeployableToken } from "../../src/codegen/tables/DeployableToken.sol";
import { TransferItem } from "../../src/systems/inventory/types.sol";
import { InventoryUtils } from "../../src/systems/inventory/InventoryUtils.sol";
import { InventoryInteractSystem } from "../../src/systems/inventory/InventoryInteractSystem.sol";
import { IERC721 } from "../../src/systems/eve-erc721-puppet/IERC721.sol";

import { EveSystem } from "../../src/systems/EveSystem.sol";

contract VendingMachineMock is EveSystem {
  ResourceId inventorySystemId = InventoryUtils.inventorySystemId();
  ResourceId ephemeralInventorySystemId = InventoryUtils.ephemeralInventorySystemId();
  /**
   * @notice Handle the interaction flow for vending machine to exchange 2x:10y items between two players
   * @dev Ideally the ration can be configured in a seperate function and stored on-chain
   * //TODO this function needs to be authorized by the builder to access inventory functions through RBAC
   * @param smartObjectId The smart object id of the smart storage unit
   * @param ephInvOwner The owner of the ephemeral inventory we want to interact with
   * @param quantity is the quanity of the item to be exchanged
   */
  function interactCall(uint256 smartObjectId, address ephInvOwner, uint256 quantity) public {
    //NOTE: Store the IN and OUT item details in table by configuring in a seperate function.
    // Its hardcoded only for testing purpose
    //Inventory Item IN data
    uint256 inItemId = uint256(keccak256(abi.encode("item:46")));
    uint256 outItemId = uint256(keccak256(abi.encode("item:45")));
    uint256 ratio = 2; // in 1 : out 2

    address inventoryOwner = IERC721(DeployableToken.getErc721Address()).ownerOf(smartObjectId);

    //Below Data should be stored in a table and fetched from there
    TransferItem[] memory inItems = new TransferItem[](1);
    inItems[0] = TransferItem(inItemId, ephInvOwner, quantity);

    TransferItem[] memory outItems = new TransferItem[](1);
    outItems[0] = TransferItem(outItemId, inventoryOwner, quantity * ratio);

    // Withdraw from ephemeralInventory and deposit to inventory
    world().call(
      ephemeralInventorySystemId,
      abi.encodeWithSelector(InventoryInteractSystem.ephemeralToInventoryTransfer.selector, smartObjectId, inItems)
    );

    // Withdraw from inventory and deposit to ephemeral inventory
    world().call(
      inventorySystemId,
      abi.encodeWithSelector(
        InventoryInteractSystem.inventoryToEphemeralTransfer.selector,
        smartObjectId,
        ephInvOwner,
        outItems
      )
    );
  }
}
