// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { DeployableTokenTable } from "../../src/codegen/tables/DeployableTokenTable.sol";
import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { TransferItem } from "../../src/modules/inventory/types.sol";

contract VendingMachineMock is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using Utils for bytes14;

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

    address inventoryOwner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);

    //Below Data should be stored in a table and fetched from there
    TransferItem[] memory inItems = new TransferItem[](1);
    inItems[0] = TransferItem(inItemId, ephInvOwner, quantity);

    TransferItem[] memory outItems = new TransferItem[](1);
    outItems[0] = TransferItem(outItemId, inventoryOwner, quantity * ratio);

    // Withdraw from ephemeralInventory and deposit to inventory
    _inventoryLib().ephemeralToInventoryTransfer(smartObjectId, inItems);
    // Withdraw from inventory and deposit to ephemeral inventory
    _inventoryLib().inventoryToEphemeralTransfer(smartObjectId, ephInvOwner, outItems);
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE))) {
      return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
    } else return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: DEPLOYMENT_NAMESPACE });
  }
}
