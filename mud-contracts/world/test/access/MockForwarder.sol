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
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

contract MockForwarder is EveSystem {
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryLib for InventoryLib.World;

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

  function unapprovedEphemeralToInventoryTransfer(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
    _inventoryLib().depositToInventory(smartObjectId, items);
  }

  function callInventoryDeposit(uint256 smartObjectId, InventoryItem[] memory items) public {
    _inventoryLib().depositToInventory(smartObjectId, items);
  }

  function callInventoryWithdraw(uint256 smartObjectId, InventoryItem[] memory items) public {
    _inventoryLib().depositToInventory(smartObjectId, items);
  }

  function callEphemeralInventoryDeposit(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
  }

  function callEphemeralInventoryWithdraw(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public {
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE,
        name: bytes16("MockForwarder")
      });
  }
}
