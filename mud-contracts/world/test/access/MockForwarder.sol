// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { IERC721 } from "../../src/modules/eve-erc721-puppet/IERC721.sol";
import { EphemeralInvItemTable } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { DeployableTokenTable } from "../../src/codegen/tables/DeployableTokenTable.sol";
import { InventoryItemTable } from "../../src/codegen/tables/InventoryItemTable.sol";

import { Utils as InventoryUtils } from "../../src/modules/inventory/Utils.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";

contract MockForwarder is EveSystem {
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryLib for InventoryLib.World;

  bytes14 constant EVE_WORLD_NAMESPACE = "eveworld";

  bytes14 constant ERC721_DEPLOYABLE_NAMESPACE = "erc721deploybl";

  ResourceId ERC721_SYSTEM_ID =
    WorldResourceIdLib.encode({
      typeId: RESOURCE_SYSTEM,
      namespace: ERC721_DEPLOYABLE_NAMESPACE,
      name: bytes16("ERC721System")
    });

  function callERC721(address from, address to, uint256 tokenId) public returns (bytes memory) {
    bytes memory returnData = world().call(ERC721_SYSTEM_ID, abi.encodeCall(IERC721.transferFrom, (from, to, tokenId)));
    return returnData;
  }

  function openEphemeralToInventoryTransfer(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    address owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
    InventoryItem[] memory inItems = new InventoryItem[](items.length);
    // check if ephemeralInventoryOwner has enough items to transfer to the inventory
    for (uint i = 0; i < items.length; i++) {
      InventoryItem memory item = items[i];
      inItems[i] = InventoryItem(item.inventoryItemId, owner, 4325, 12, 100, item.quantity);
      if (
        EphemeralInvItemTable.get(smartObjectId, item.inventoryItemId, ephemeralInventoryOwner).quantity < item.quantity
      ) {
        revert IInventoryErrors.Inventory_InvalidTransferItemQuantity(
          "MockForwarder: Not enough items to transfer",
          smartObjectId,
          "EPHEMERAL",
          ephemeralInventoryOwner,
          item.inventoryItemId,
          item.quantity
        );
      }
    }

    // withdraw the items from ephemeral and deposit to inventory table
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
    // transfer items to the ssu owner
    _inventoryLib().depositToInventory(smartObjectId, inItems);
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: EVE_WORLD_NAMESPACE });
  }

  function _systemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: bytes14("eveworld"),
        name: bytes16("MockForwarder")
      });
  }
}
