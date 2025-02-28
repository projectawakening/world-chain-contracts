// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Core MUD/Lattice imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Type definitions
import { InventoryItem, TransferItem } from "../inventory/types.sol";
import { State, SmartObjectData } from "../deployable/types.sol";
import { WorldPosition } from "../location/types.sol";
import { EntityRecordData } from "../entity-record/types.sol";
import { CreateAndAnchorDeployableParams } from "../deployable/types.sol";
import { State as CommonState } from "../../../../codegen/common.sol";

// Constants
import { CRUDE_LIFT } from "../constants.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "./../constants.sol";

// Table/codegen imports
import { Fuel, CrudeLift, CrudeLiftData, LocationData, Lens, DeployableToken, Rift, InventoryItem as InventoryItemTable, Inventory, EntityRecord, DeployableState } from "../../codegen/index.sol";

// System imports
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { ephemeralInventorySystem } from "../../codegen/systems/EphemeralInventorySystemLib.sol";
import { inventoryInteractSystem } from "../../codegen/systems/InventoryInteractSystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";
import { smartAssemblySystem } from "../../codegen/systems/SmartAssemblySystemLib.sol";
import { crudeLiftSystem } from "../../codegen/systems/CrudeLiftSystemLib.sol";
import { locationSystem } from "../../codegen/systems/LocationSystemLib.sol";
import { entityRecordSystem } from "../../codegen/systems/EntityRecordSystemLib.sol";

// Local system imports
import { DeployableSystem } from "../deployable/DeployableSystem.sol";
import { FuelSystem } from "../fuel/FuelSystem.sol";

uint256 constant CRUDE_MATTER = 1;
uint256 constant LENS = 2;

contract CrudeLiftSystem is SmartObjectFramework {
  error LensNotInserted();
  error LensExhausted();
  error LensAlreadyInserted();
  error LensExpired();
  error CannotRemoveLensWhileMining();
  error AlreadyMining();
  error NotMining();
  error RiftNotFoundOrDepleted();
  error InsufficientCrude();
  error RiftCollapsed();
  error CrudeLiftWrongState(uint256 crudeLiftId, State currentState);

  function createAndAnchorCrudeLift(
    CreateAndAnchorDeployableParams memory params,
    uint256 storageCapacity,
    uint256 ephemeralStorageCapacity
  ) public context access(params.smartObjectId) scope(getCrudeLiftClassId()) {
    entitySystem.instantiate(getCrudeLiftClassId(), params.smartObjectId, params.smartObjectData.owner);

    deployableSystem.createAndAnchorDeployable(params);
    inventorySystem.setInventoryCapacity(params.smartObjectId, storageCapacity);
    ephemeralInventorySystem.setEphemeralInventoryCapacity(params.smartObjectId, ephemeralStorageCapacity);
  }

  function insertLens(uint256 crudeLiftId) public {
    if (CrudeLift.getLensId(crudeLiftId) != 0) revert LensAlreadyInserted();

    uint256[] memory items = Inventory.getItems(crudeLiftId);
    uint256 foundLensId = 0;
    for (uint256 i = 0; i < items.length; i++) {
      // how do i do this?
      if (EntityRecord.getTypeId(items[i]) == LENS) {
        foundLensId = items[i];
        break;
      }
    }
    if (foundLensId == 0) revert LensNotInserted();
    if (Lens.getExhausted(foundLensId)) revert LensExhausted();

    // If durability is 0 but not exhausted, it means the lens has not been initialized onchain yet
    if (Lens.getDurability(foundLensId) == 0) {
      // TODO durability needs to get set when a Lens is crafted
      Lens.setDurability(foundLensId, 100);
    }

    CrudeLift.setLensId(crudeLiftId, foundLensId);
  }

  function startMining(uint256 crudeLiftId, uint256 riftId, uint256 miningRate) public {
    State currentState = DeployableState.getCurrentState(crudeLiftId);
    if (currentState != State.ONLINE) {
      revert CrudeLiftWrongState(crudeLiftId, currentState);
    }

    CrudeLiftData memory lift = CrudeLift.get(crudeLiftId);

    if (lift.lensId == 0) revert LensNotInserted();
    if (lift.startMiningTime != 0) revert AlreadyMining();
    if (getCrudeAmount(riftId) == 0) revert RiftNotFoundOrDepleted();
    if (Rift.getMiningCrudeLiftId(riftId) != 0) revert AlreadyMining();
    if (Rift.getCollapsedAt(riftId) != 0) revert RiftCollapsed();

    CrudeLift.setStartMiningTime(crudeLiftId, block.timestamp);
    CrudeLift.setMiningRiftId(crudeLiftId, riftId);
    CrudeLift.setMiningRate(crudeLiftId, miningRate);
    Rift.setMiningCrudeLiftId(riftId, crudeLiftId);
  }

  function stopMining(uint256 crudeLiftId) public {
    CrudeLiftData memory lift = CrudeLift.get(crudeLiftId);
    if (lift.startMiningTime == 0) revert NotMining();

    uint256 miningDuration = block.timestamp - lift.startMiningTime;

    uint256 riftId = CrudeLift.getMiningRiftId(crudeLiftId);
    uint256 riftCollapsedAt = Rift.getCollapsedAt(riftId);
    uint256 miningTimeUntilRiftCollapse = type(uint256).max;
    if (riftCollapsedAt > 0) {
      miningTimeUntilRiftCollapse = riftCollapsedAt - lift.startMiningTime;
    }

    if (miningTimeUntilRiftCollapse < miningDuration) {
      miningDuration = miningTimeUntilRiftCollapse;
    }

    // cannot call view functions from system libs right now
    bytes memory data = IWorldWithContext(_world()).call(
      fuelSystem.toResourceId(),
      abi.encodeCall(FuelSystem.currentFuelAmountInWei, (crudeLiftId))
    );
    uint256 currentFuel = abi.decode(data, (uint256));
    // fuel ran out as some point in the past, need to figure out how many blocks we actually mined for
    if (currentFuel < ONE_UNIT_IN_WEI) {
      uint256 fuelConsumptionInterval = Fuel.getFuelConsumptionIntervalInSeconds(crudeLiftId);
      uint256 startingFuel = Fuel.getFuelAmount(crudeLiftId) / ONE_UNIT_IN_WEI;
      uint256 secondsMining = (startingFuel / fuelConsumptionInterval);
      miningDuration = secondsMining < miningDuration ? secondsMining : miningDuration;
    }

    uint256 remainingLensDurability = Lens.getDurability(CrudeLift.getLensId(crudeLiftId));
    // the lens was exhaused at some point during mining
    if (miningDuration >= remainingLensDurability) {
      miningDuration = remainingLensDurability;
      Lens.setExhausted(CrudeLift.getLensId(crudeLiftId), true);
      Lens.setDurability(CrudeLift.getLensId(crudeLiftId), 0);
    } else {
      Lens.setDurability(CrudeLift.getLensId(crudeLiftId), remainingLensDurability - miningDuration);
    }

    uint256 crudeMined = calculateCrudeMined(CrudeLift.getMiningRate(crudeLiftId), miningDuration);

    uint256 remainingCrudeAmount = getCrudeAmount(riftId);
    if (crudeMined > remainingCrudeAmount) {
      crudeMined = remainingCrudeAmount;
    }

    uint256 remainingInventoryCapacity = Inventory.getCapacity(crudeLiftId) - Inventory.getUsedCapacity(crudeLiftId);
    if (crudeMined > remainingInventoryCapacity) {
      // TODO how much capacity does Crude take up?
      crudeMined = remainingInventoryCapacity;
    }

    removeCrude(riftId, crudeMined);
    addCrude(crudeLiftId, crudeMined);

    // Reset mining state
    CrudeLift.setStartMiningTime(crudeLiftId, 0);
    CrudeLift.setMiningRiftId(crudeLiftId, 0);

    Rift.setMiningCrudeLiftId(riftId, 0);

    // Fuel updates at the end so the Lift can be brought offline after interacting with inventory
    fuelSystem.updateFuel(crudeLiftId);
  }

  function removeLens(uint256 smartObjectId, address receiver) public {
    if (CrudeLift.getLensId(smartObjectId) == 0) revert LensNotInserted();
    if (CrudeLift.getStartMiningTime(smartObjectId) != 0) revert CannotRemoveLensWhileMining();

    CrudeLift.setLensId(smartObjectId, 0);

    TransferItem[] memory items = new TransferItem[](1);
    items[0] = TransferItem({ inventoryItemId: CrudeLift.getLensId(smartObjectId), quantity: 1, owner: receiver });
    inventoryInteractSystem.inventoryToEphemeralTransfer(smartObjectId, receiver, items);
  }

  function calculateCrudeMined(uint256 miningRate, uint256 duration) internal pure returns (uint256) {
    return (duration * miningRate);
  }

  function addCrude(uint256 smartObjectId, uint256 amount) public {
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: uint256(keccak256(abi.encodePacked("crude", CRUDE_MATTER))),
      owner: address(0),
      itemId: 0,
      typeId: CRUDE_MATTER,
      volume: 1,
      quantity: amount
    });

    inventorySystem.createAndDepositItemsToInventory(smartObjectId, items);
  }

  function removeCrude(uint256 smartObjectId, uint256 amount) public {
    uint256 crudeAmount = getCrudeAmount(smartObjectId);
    if (crudeAmount < amount) revert InsufficientCrude();

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({
      inventoryItemId: uint256(keccak256(abi.encodePacked("crude", CRUDE_MATTER))),
      owner: address(0),
      itemId: 0,
      typeId: CRUDE_MATTER,
      volume: 1,
      quantity: amount
    });

    inventorySystem.withdrawFromInventory(smartObjectId, items);
  }

  function clearCrude(uint256 smartObjectId) public {
    uint256 crudeAmount = getCrudeAmount(smartObjectId);
    if (crudeAmount == 0) return;

    removeCrude(smartObjectId, crudeAmount);
  }

  function getCrudeAmount(uint256 smartObjectId) public view returns (uint256) {
    uint256[] memory inventoryItems = Inventory.getItems(smartObjectId);
    uint256 foundCrudeId = 0;
    for (uint256 i = 0; i < inventoryItems.length; i++) {
      // how do i do this?
      if (EntityRecord.getTypeId(inventoryItems[i]) == CRUDE_MATTER) {
        foundCrudeId = inventoryItems[i];
        break;
      }
    }
    if (foundCrudeId == 0) return 0;

    return InventoryItemTable.getQuantity(smartObjectId, foundCrudeId);
  }

  function getCrudeLiftClassId() public pure returns (uint256) {
    return uint256(bytes32("CL"));
  }
}
