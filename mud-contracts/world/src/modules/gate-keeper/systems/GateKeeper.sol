// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE, GATE_KEEPER_CLASS_ID } from "@eveworld/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { SmartStorageUnitLib } from "../../smart-storage-unit/SmartStorageUnitLib.sol";

import { IGateKeeperErrors } from "../IGateKeeperErrors.sol";

import { EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";

import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { InventoryItemTable } from "../../../codegen/tables/InventoryItemTable.sol";
import { GateKeeperTable } from "../../../codegen/tables/GateKeeperTable.sol";

import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../entity-record/Utils.sol";
import { Utils as InventoryUtils } from "../../inventory/Utils.sol";
import { Utils } from "../Utils.sol";

import { SmartObjectData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { InventoryItem } from "../../inventory/types.sol";

/**
 * @title GateKeep storage unit
 * @notice contains hook logic that modifies a vanilla SSU into a GateKeep storage unit, war-effort-style
 * users can only deposit a pre-determined kind of items in it, no withdrawals are allowed (transaction)
 */
contract GateKeeper is EveSystem, IGateKeeperErrors {
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
  function createAndAnchorGateKeeper(
    uint256 smartObjectId,
    EntityRecordTableData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionPerMinute,
    uint256 fuelMaxCapacity,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public hookable(smartObjectId, _systemId()) {
    SmartStorageUnitLib.World(IBaseWorld(_world()), _namespace()).createAndAnchorSmartStorageUnit(
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
    SmartObjectLib.World(IBaseWorld(_world()), _namespace()).tagEntity(smartObjectId, GATE_KEEPER_CLASS_ID);
  }

  function setAcceptedItemTypeId(
    uint256 smartObjectId,
    uint256 entityTypeId
  ) public onlyAssociatedModule(smartObjectId, _systemId()) hookable(smartObjectId, _systemId()) {
    GateKeeperTable.setAcceptedItemTypeId(_namespace().gateKeeperTableId(), smartObjectId, entityTypeId);
  }

  function setTargetQuantity(
    uint256 smartObjectId,
    uint256 targetItemQuantity
  ) public onlyAssociatedModule(smartObjectId, _systemId()) hookable(smartObjectId, _systemId()) {
    GateKeeperTable.setTargetQuantity(_namespace().gateKeeperTableId(), smartObjectId, targetItemQuantity);
  }

  function ephemeralToInventoryTransferHook(
    uint256 smartObjectId,
    address ephemeralInventoryOwner, // TODO that part is meant to be initialMsgSender()
    InventoryItem[] memory items
  ) public {
    if (items.length != 1) revert GateKeeper_WrongItemArrayLength();

    uint256 expectedItemTypeId = GateKeeperTable.getAcceptedItemTypeId(_namespace().gateKeeperTableId(), smartObjectId);
    if (items[0].typeId != expectedItemTypeId) revert GateKeeper_WrongDepositType(expectedItemTypeId, items[0].typeId);

    uint256 storedQuantity = InventoryItemTable.getQuantity(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].typeId
    );
    uint256 targetQuantity = GateKeeperTable.getTargetQuantity(_namespace().gateKeeperTableId(), smartObjectId);
    if (storedQuantity + items[0].quantity > targetQuantity) {
      revert GateKeeper_DepositOverTargetLimit();
    } else if (storedQuantity + items[0].quantity == targetQuantity) {
      GateKeeperTable.setIsGoalReached(_namespace().gateKeeperTableId(), smartObjectId, true);
    }

    // must be added as a BeforeHook to the related Inventory function, to GATE_KEEPER_CLASS_ID tagged entities
    // _;
  }

  function depositToInventoryHook(uint256 smartObjectId, InventoryItem[] memory items) public {
    if (items.length != 1) revert GateKeeper_WrongItemArrayLength();

    uint256 expectedItemTypeId = GateKeeperTable.getAcceptedItemTypeId(_namespace().gateKeeperTableId(), smartObjectId);
    if (items[0].typeId != expectedItemTypeId) revert GateKeeper_WrongDepositType(expectedItemTypeId, items[0].typeId);

    uint256 storedQuantity = InventoryItemTable.getQuantity(
      INVENTORY_DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      items[0].typeId
    );
    uint256 targetQuantity = GateKeeperTable.getTargetQuantity(_namespace().gateKeeperTableId(), smartObjectId);
    if (storedQuantity + items[0].quantity > targetQuantity) {
      revert GateKeeper_DepositOverTargetLimit();
    } else if (storedQuantity + items[0].quantity == targetQuantity) {
      GateKeeperTable.setIsGoalReached(_namespace().gateKeeperTableId(), smartObjectId, true);
    }

    // must be added as a BeforeHook to the related Inventory function, to GATE_KEEPER_CLASS_ID tagged entities
    // _;
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().gateKeeperSystemId();
  }
}
