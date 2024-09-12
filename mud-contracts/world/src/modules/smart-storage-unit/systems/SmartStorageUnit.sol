// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { SMART_STORAGE_MODULE_NAME, SMART_STORAGE_MODULE_NAMESPACE } from "../constants.sol";
import { EntityRecordData, WorldPosition } from "../types.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { EntityTable } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE, OBJECT } from "@eveworld/common-constants/src/constants.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";

import { ClassConfig } from "../../../codegen/tables/ClassConfig.sol";

import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { InventoryLib } from "../../inventory/InventoryLib.sol";

import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";

import { AccessModified } from "../../access/systems/AccessModified.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";
import { Utils as SmartObjectFrameworkUtils } from "@eveworld/smart-object-framework/src/utils.sol";
import { Utils } from "../Utils.sol";

import { SmartObjectData, SmartAssemblyType } from "../../smart-deployable/types.sol";
import { InventoryItem } from "../../inventory/types.sol";
import { ISmartStorageUnitErrors } from "../ISmartStorageUnitErrors.sol";

contract SmartStorageUnit is AccessModified, EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using SmartObjectFrameworkUtils for bytes14;
  using EntityRecordLib for EntityRecordLib.World;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectLib for SmartObjectLib.World;

  error SmartStorageUnitERC721AlreadyInitialized();

  /**
   * @notice Create and anchor a smart storage unit
   * @dev Create and anchor a smart storage unit by smart object id
   * @param smartStorageUnitId The smart object id
   * @param entityRecordData The entity record data of the smart object
   * @param smartObjectData is the token metadata of the smart object
   * @param worldPosition The position of the smart object in the game
   * @param storageCapacity The storage capacity of the smart storage unit
   * @param ephemeralStorageCapacity The personal storage capacity of the smart storage unit
   */
  function createAndAnchorSmartStorageUnit(
    uint256 smartStorageUnitId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public onlyAdmin hookable(smartStorageUnitId, _systemId()) {
    {
      uint256 classId = ClassConfig.getClassId(_namespace().classConfigTableId(), _systemId());

      if (classId == 0) {
        revert ISmartStorageUnitErrors.SmartStorageUnit_UndefinedClassId();
      }

      if (EntityTable.getDoesExists(_namespace().entityTableTableId(), smartStorageUnitId) == false) {
        // register smartStorageUnitId as an object
        _smartObjectLib().registerEntity(smartStorageUnitId, OBJECT);
        // tag this object's entity Id to a set of defined classIds
        _smartObjectLib().tagEntity(smartStorageUnitId, classId);
      }
    }
    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
    _entityRecordLib().createEntityRecord(
      smartStorageUnitId,
      entityRecordData.itemId,
      entityRecordData.typeId,
      entityRecordData.volume
    );

    _smartDeployableLib().registerDeployable(
      smartStorageUnitId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionPerMinute,
      fuelMaxCapacity
    );
    _smartDeployableLib().setSmartAssemblyType(smartStorageUnitId, SmartAssemblyType.SMART_STORAGE_UNIT);

    LocationTableData memory locationData = LocationTableData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    _smartDeployableLib().anchor(smartStorageUnitId, locationData);

    _inventoryLib().setInventoryCapacity(smartStorageUnitId, storageCapacity);
    _inventoryLib().setEphemeralInventoryCapacity(smartStorageUnitId, ephemeralStorageCapacity);
  }

  /**
   * @notice Create an item on chain and deposit it to the inventory
   * @dev Create an item by smart object id and deposit it to the inventory
   * //TODO only server account can create items on-chain
   * //TODO Represent item as a ERC1155 asset with ownership on-chain
   * @param smartStorageUnitId The smart object id
   * @param items The item to store in a inventory
   */
  function createAndDepositItemsToInventory(
    uint256 smartStorageUnitId,
    InventoryItem[] memory items
  ) public onlyAdmin hookable(smartStorageUnitId, _systemId()) {
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
    _inventoryLib().depositToInventory(smartStorageUnitId, items);
  }

  /**
   * @notice Create an item on chain and deposit it to the ephemeral inventory
   * @dev Create an item by smart object id and deposit it to the ephemeral inventory
   * //TODO only server account can create items on-chain
   * //TODO Represent item as a ERC1155 asset with ownership on-chain
   * @param smartStorageUnitId The smart object id
   * @param ephemeralInventoryOwner The owner of the inventory
   * @param items The item to store in a inventory
   */
  function createAndDepositItemsToEphemeralInventory(
    uint256 smartStorageUnitId,
    address ephemeralInventoryOwner,
    InventoryItem[] memory items
  ) public onlyAdmin hookable(smartStorageUnitId, _systemId()) {
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
    _inventoryLib().depositToEphemeralInventory(smartStorageUnitId, ephemeralInventoryOwner, items);
  }

  function setSSUClassId(
    uint256 classId
  ) public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    ClassConfig.setClassId(_namespace().classConfigTableId(), _systemId(), classId);
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
  function setDeployableMetadata(
    uint256 smartObjectId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public onlyAdminOrObjectOwner(smartObjectId) hookable(smartObjectId, _systemId()) {
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

  function _smartObjectLib() internal view returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ iface: IBaseWorld(_world()), namespace: SMART_OBJECT_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartStorageUnitSystemId();
  }
}
