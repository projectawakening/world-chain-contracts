// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE, SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { SmartStorageUnitLib } from "../../smart-storage-unit/SmartStorageUnitLib.sol";

import { IItemSellerErrors } from "../IItemSellerErrors.sol";

import { EntityRecordData } from "../../smart-storage-unit/types.sol";

import { EntityRecordTable } from "../../../codegen/tables/EntityRecordTable.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { InventoryTable } from "../../../codegen/tables/InventoryTable.sol";
import { InventoryItemTable, InventoryItemTableData } from "../../../codegen/tables/InventoryItemTable.sol";
import { ItemSellerTable } from "../../../codegen/tables/ItemSellerTable.sol";

import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";
import { Utils as InventoryUtils } from "../../inventory/Utils.sol";
import { Utils } from "../Utils.sol";

import { SmartObjectData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { InventoryItem } from "../../inventory/types.sol";

import { OBJECT, ITEM_SELLER_CLASS_ID } from "../../../utils/ModulesInitializationLibrary.sol";

/**
 * @title GateKeep storage unit
 * @notice contains hook logic that modifies a vanilla SSU into a GateKeep storage unit, war-effort-style
 * users can only deposit a pre-determined kind of items in it, no withdrawals are allowed (transaction)
 */
contract ItemSeller is EveSystem, IItemSellerErrors {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryUtils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;
  using SmartStorageUnitLib for SmartStorageUnitLib.World;

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
  function createAndAnchorItemSeller(
    uint256 smartObjectId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public hookable(smartObjectId, _systemId()) {
    SmartStorageUnitLib
      .World(IBaseWorld(_world()), SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE)
      .createAndAnchorSmartStorageUnit(
        smartObjectId,
        entityRecordData,
        smartObjectData,
        worldPosition,
        fuelUnitVolume,
        fuelConsumptionPerMinute,
        fuelMaxCapacity,
        storageCapacity,
        ephemeralStorageCapacity
      );
    SmartObjectLib.World(IBaseWorld(_world()), SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEntity(smartObjectId, OBJECT);
    SmartObjectLib.World(IBaseWorld(_world()), SMART_OBJECT_DEPLOYMENT_NAMESPACE).tagEntity(
      smartObjectId,
      ITEM_SELLER_CLASS_ID
    );
  }

  /**
   * @notice Sets the accepted item type ID for a seller in a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param entityTypeId The ID of the item type that is accepted by the seller.
   */
  function setItemSellerAcceptedItemTypeId(
    uint256 smartObjectId,
    uint256 entityTypeId
  ) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setAcceptedItemTypeId(_namespace().itemSellerTableId(), smartObjectId, entityTypeId);
  }

  /**
   * @notice Sets the allow purchase status for a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param isAllowed The new purchase status (true to allow purchase, false to disallow).
   */
  function setAllowPurchase(uint256 smartObjectId, bool isAllowed) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setIsPurchaseAllowed(_namespace().itemSellerTableId(), smartObjectId, isAllowed);
  }

  /**
   * @notice Sets the allow buyback status for a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param isAllowed The new buyback status (true to allow buyback, false to disallow).
   */
  function setAllowBuyback(uint256 smartObjectId, bool isAllowed) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setIsBuybackAllowed(_namespace().itemSellerTableId(), smartObjectId, isAllowed);
  }

  /**
   * @notice Sets the ERC20 purchase price for a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param purchasePriceInWei The target item quantity for the purchase price.
   */
  function setERC20PurchasePrice(uint256 smartObjectId, uint256 purchasePriceInWei) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setErc20PurchasePriceWei(_namespace().itemSellerTableId(), smartObjectId, purchasePriceInWei);
  }

  /**
   * @notice Sets the ERC20 buyback price for a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param buybackPriceInWei The target item quantity for the buyback price.
   */
  function setERC20BuybackPrice(uint256 smartObjectId, uint256 buybackPriceInWei) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setErc20BuybackPriceWei(_namespace().itemSellerTableId(), smartObjectId, buybackPriceInWei);
  }

  /**
   * @notice Sets the ERC20 currency address for a given smart object.
   * @param smartObjectId The ID of the smart object.
   * @param erc20Address The address of the ERC20 currency.
   */
  function setERC20Currency(uint256 smartObjectId, address erc20Address) public hookable(smartObjectId, _systemId()) {
    ItemSellerTable.setErc20Address(_namespace().itemSellerTableId(), smartObjectId, erc20Address);
  }

  /**
   * @notice Hook that is called when a seller deposits items to the inventory of a smart object.
   * @param smartObjectId The ID of the smart object.
   * @param items The list of inventory items being deposited.
   */
  function itemSellerDepositToInventoryHook(uint256 smartObjectId, InventoryItem[] memory items) public hookable(smartObjectId, _systemId()) {

  }

  /**
   * @notice Hook that is called when a seller withdraws items from the inventory of a smart object.
   * @param smartObjectId The ID of the smart object.
   * @param items The list of inventory items being withdrawn.
   */
  function itemSellerWithdrawFromInventoryHook(uint256 smartObjectId, InventoryItem[] memory items) public hookable(smartObjectId, _systemId()) {

  }

  function _getTypeIdQuantity(uint256 smartObjectId, uint256 reqTypeId) internal view returns (uint256 quantity) {
    uint256[] memory items = InventoryTable.getItems(INVENTORY_DEPLOYMENT_NAMESPACE.inventoryTableId(), smartObjectId);
    for (uint i = 0; i < items.length; i++) {
      uint256 itemTypeId = EntityRecordTable.getTypeId(
        ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(),
        items[i]
      );
      if (itemTypeId == reqTypeId) {
        quantity += InventoryItemTable.getQuantity(
          INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
          smartObjectId,
          items[i]
        );
      }
    }
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().itemSellerSystemId();
  }
}
