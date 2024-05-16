// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { SMART_STORAGE_MODULE_NAME, SMART_STORAGE_MODULE_NAMESPACE } from "../constants.sol";
import { WorldPosition } from "../types.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

import { EveSystem } from "@eveworld/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SSU_CLASS_ID } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eveworld/frontier-smart-object-framework/src/SmartObjectLib.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";

import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { InventoryLib } from "../../inventory/InventoryLib.sol";

import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";

import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";
import { Utils } from "../Utils.sol";

import { SmartObjectData } from "../../smart-deployable/types.sol";
import { InventoryItem } from "../../inventory/types.sol";

contract SmartStorageUnit is EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;

  error SmartStorageUnitERC721AlreadyInitialized();

  /**
   * @notice Create and anchor a smart storage unit
   * @dev Create and anchor a smart storage unit by smart object id
   * @param smartObjectId The smart object id
   * @param entityRecordData The entity record data of the smart object
   * @param smartObjectData is the token metadata of the smart object
   * @param worldPosition The position of the smart object in the game
   * @param storageCapacity The storage capacity of the smart storage unit
   * @param ephemeralStorageCapacity The personal storage capacity of the smart storage unit
   */
  function createAndAnchorSmartStorageUnit(
    uint256 smartObjectId,
    EntityRecordTableData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public {
    _smartDeployableLib().registerDeployable(
      smartObjectId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity
    );
    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
    _entityRecordLib().createEntityRecord(
      smartObjectId,
      entityRecordData.itemId,
      entityRecordData.typeId,
      entityRecordData.volume
    );

    SmartObjectLib.World(IBaseWorld(_world()), _namespace()).tagEntity(smartObjectId, SSU_CLASS_ID);
    LocationTableData memory locationData = LocationTableData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    _smartDeployableLib().anchor(smartObjectId, locationData);

    _inventoryLib().setInventoryCapacity(smartObjectId, storageCapacity);
    _inventoryLib().setEphemeralInventoryCapacity(smartObjectId, ephemeralStorageCapacity);
  }

  /**
   * @notice Create an item on chain and deposit it to the inventory
   * @dev Create an item by smart object id and deposit it to the inventory
   * //TODO only server account can create items on-chain
   * //TODO Represent item as a ERC1155 asset with ownership on-chain
   * @param smartObjectId The smart object id
   * @param items The item to store in a inventory
   */
  function createAndDepositItemsToInventory(
    uint256 smartObjectId,
    InventoryItem[] memory items
  ) public onlyAssociatedModule(smartObjectId, _systemId()) {
    for (uint256 i = 0; i < items.length; i++) {
      //Check if the item exists on-chain if not Create entityRecord
      _entityRecordLib().createEntityRecord(
        items[i].inventoryItemId,
        items[i].itemId,
        items[i].typeId,
        items[i].volume
      );
    }
    //Deposit item to the inventory
    _inventoryLib().depositToInventory(smartObjectId, items);
  }

  /**
   * @notice Create an item on chain and deposit it to the ephemeral inventory
   * @dev Create an item by smart object id and deposit it to the ephemeral inventory
   * //TODO only server account can create items on-chain
   * //TODO Represent item as a ERC1155 asset with ownership on-chain
   * @param smartObjectId The smart object id
   * @param ephemeralInventoryOwner The owner of the inventory
   * @param items The item to store in a inventory
   */
  function createAndDepositItemsToEphemeralInventory(
    uint256 smartObjectId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public onlyAssociatedModule(smartObjectId, _systemId()) {
    //Check if the item exists on-chain if not Create entityRecord
    for (uint256 i = 0; i < items.length; i++) {
      _entityRecordLib().createEntityRecord(
        items[i].inventoryItemId,
        items[i].itemId,
        items[i].typeId,
        items[i].volume
      );
    }
    //Deposit item to the ephemeral inventory
    // TODO: This _might_ clash with online fuel, since that would require the underlying deployable to be funded in fuel
    _inventoryLib().depositToEphemeralInventory(smartObjectId, ephemeralInventoryOwner, items);
  }

  /**
   * @notice Create metadata of a smart deployable
   * @dev Create metadata of a smart deployable by smart object id
   * //TODO This function will be moved to ipfs in future
   * @param smartObjectId The smart object id
   * @param name The name of the smart deployable
   * @param dappURL The dapp URL of the smart deployable
   * @param description The description of the smart deployable
   */
  function setDeploybaleMetadata(
    uint256 smartObjectId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public onlyAssociatedModule(smartObjectId, _systemId()) {
    _entityRecordLib().createEntityRecordOffchain(smartObjectId, name, dappURL, description);
  }

  function _entityRecordLib() internal view returns (EntityRecordLib.World memory) {
    return EntityRecordLib.World({ iface: IBaseWorld(_world()), namespace: ENTITY_RECORD_DEPLOYMENT_NAMESPACE });
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: INVENTORY_DEPLOYMENT_NAMESPACE });
  }

  function _smartDeployableLib() internal view returns (SmartDeployableLib.World memory) {
    return SmartDeployableLib.World({ iface: IBaseWorld(_world()), namespace: SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartStorageUnitSystemId();
  }
}
