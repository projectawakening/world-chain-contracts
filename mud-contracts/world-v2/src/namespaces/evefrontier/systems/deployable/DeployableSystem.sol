// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { TagId, TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { EntityTagMap } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/EntityTagMap.sol";

// Local namespace tables
import { GlobalDeployableState, GlobalDeployableStateData, DeployableState, DeployableStateData, CharactersByAccount, Fuel, FuelData, Location, LocationData, Inventory, InventoryItem, EntityRecord, SmartGateLink } from "../../codegen/index.sol";

// Local namespace systems
import { FuelSystem } from "../fuel/FuelSystem.sol";
import { LocationSystem } from "../location/LocationSystem.sol";
import { locationSystem } from "../../codegen/systems/LocationSystemLib.sol";
import { smartAssemblySystem } from "../../codegen/systems/SmartAssemblySystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { smartGateSystem } from "../../codegen/systems/SmartGateSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "./types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "./../constants.sol";
import { TAG_TYPE_RESOURCE_RELATION } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { OwnershipHelper } from "../../libraries/OwnershipHelper.sol";

/**
 * @title DeployableSystem
 * @author CCP Games
 * DeployableSystem stores the deployable state of a smart object on-chain
 */
contract DeployableSystem is SmartObjectFramework {
  error Deployable_IncorrectState(uint256 smartObjectId, State currentState);
  error Deployable_NoFuel(uint256 smartObjectId);
  error Deployable_StateTransitionPaused();
  error Deployable_TooMuchFuelDeposited(uint256 smartObjectId, uint256 amountDeposited);
  error Deployable_InvalidFuelConsumptionInterval(uint256 smartObjectId);
  error Deployable_InvalidObjectOwner(string message, address smartObjectOwner, uint256 smartObjectId);

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused()) {
      revert Deployable_StateTransitionPaused();
    }
    _;
  }

  /**
   * @dev creates and anchors a deployable smart object
   * @param params struct containing all parameters for creating and anchoring a deployable
   */
  function createAndAnchor(
    CreateAndAnchorParams memory params
  ) public context access(params.smartObjectId) scope(params.smartObjectId) {
    // Create the smart assembly object
    smartAssemblySystem.createAssembly(params.smartObjectId, params.assemblyType, params.entityRecordParams);

    createDeployable(
      params.smartObjectId,
      params.owner,
      params.fuelUnitVolume,
      params.fuelConsumptionIntervalInSeconds,
      params.fuelMaxCapacity
    );

    anchor(params.smartObjectId, params.owner, params.locationData);
  }

  /**
   * TODO: restrict this to smartObjectIds that exist
   * @dev creates a new deployable smart object
   * @param smartObjectId id of the smart object
   * @param owner the owner of the smart object
   * @param fuelUnitVolume the fuel unit volume in wei
   * @param fuelConsumptionIntervalInSeconds the fuel consumption per minute in wei
   * @param fuelMaxCapacity the fuel max capacity in wei
   */
  function createDeployable(
    uint256 smartObjectId,
    address owner,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.NULL) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    if (fuelConsumptionIntervalInSeconds < 1) {
      revert Deployable_InvalidFuelConsumptionInterval(smartObjectId);
    }

    // revert if the given smart object owner is not a valid character
    if (CharactersByAccount.get(owner) == 0) {
      revert Deployable_InvalidObjectOwner(
        "SmartDeployableSystem: Smart Object owner is not a valid Smart Character",
        owner,
        smartObjectId
      );
    }

    // TODO: the following is a candidate for hook logic
    // check if this deploybale has inventory scoped to itset the initial inventory data version to 1
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    TagId systemTagId = TagIdLib.encode(
      TAG_TYPE_RESOURCE_RELATION,
      bytes30(ResourceId.unwrap(inventorySystem.toResourceId()))
    );
    if (EntityTagMap.getHasTag(classId, systemTagId)) {
      Inventory.setVersion(smartObjectId, 1);
    }

    // Use OwnershipSystem to track ownership
    ownershipSystem.assignOwner(smartObjectId, owner);

    DeployableState.set(
      smartObjectId,
      block.timestamp,
      State.NULL,
      State.UNANCHORED,
      false,
      0,
      block.number,
      block.timestamp
    );

    fuelSystem.configureFuelParameters(
      smartObjectId,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity,
      0
    );
  }

  /**
   * @dev destroys a deployable smart object
   * @param smartObjectId id of the smart object
   */
  function destroyDeployable(
    uint256 smartObjectId
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }
    // increment the inventory data version (this will make ALL previous inventory item data stale)
    // reset the used capacity to 0
    // TODO: the following is a candidate for hook logic and optimization
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    TagId systemTagId = TagIdLib.encode(
      TAG_TYPE_RESOURCE_RELATION,
      bytes30(ResourceId.unwrap(inventorySystem.toResourceId()))
    );
    if (EntityTagMap.getHasTag(classId, systemTagId)) {
      Inventory.setVersion(smartObjectId, Inventory.getVersion(smartObjectId) + 1);
      Inventory.setUsedCapacity(smartObjectId, 0);
    }

    // check if the deploybale is a smart gate and unlink it
    // TODO : move this to hook logic
    TagId gateSystemTagId = TagIdLib.encode(
      TAG_TYPE_RESOURCE_RELATION,
      bytes30(ResourceId.unwrap(smartGateSystem.toResourceId()))
    );
    if (EntityTagMap.getHasTag(classId, gateSystemTagId) && SmartGateLink.getIsLinked(smartObjectId)) {
      uint256 destinationGateId = SmartGateLink.getDestinationGateId(smartObjectId);
      smartGateSystem.unlinkGates(smartObjectId, destinationGateId);
    }

    // Remove ownership tracking of the deployable smart object
    address owner = ownershipSystem.owner(smartObjectId);
    ownershipSystem.removeOwner(smartObjectId, owner);

    _setDeployableState(smartObjectId, previousState, State.DESTROYED);
    DeployableState.setIsValid(smartObjectId, false);
  }

  /**
   * @dev brings a deployable smart object online
   * @param smartObjectId id of the smart object
   */
  function bringOnline(uint256 smartObjectId) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.ANCHORED) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    fuelSystem.updateFuel(smartObjectId);

    uint256 currentFuel = Fuel.getFuelAmount(smartObjectId);
    if (currentFuel < ONE_UNIT_IN_WEI) revert Deployable_NoFuel(smartObjectId);

    fuelSystem.setFuelAmount(smartObjectId, currentFuel - ONE_UNIT_IN_WEI);

    _setDeployableState(smartObjectId, previousState, State.ONLINE);
  }

  /**
   * @dev brings a deployable smart object offline
   * @param smartObjectId id of the smart object
   */
  function bringOffline(uint256 smartObjectId) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.ONLINE) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    fuelSystem.updateFuel(smartObjectId);
    _bringOffline(smartObjectId, previousState);
  }

  /**
   * @dev anchors a smart deployable
   * @param smartObjectId on-chain of the deployable
   * @param locationData the location data of the object
   */
  function anchor(
    uint256 smartObjectId,
    address owner,
    LocationData memory locationData
  ) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.UNANCHORED) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }
    _setDeployableState(smartObjectId, previousState, State.ANCHORED);
    // assign ownership tracking of the deployable smart object
    address currentOwner = OwnershipHelper.getOwner(smartObjectId);
    if (currentOwner == address(0)) {
      ownershipSystem.assignOwner(smartObjectId, owner);
    } else if (currentOwner != address(0) && currentOwner != owner) {
      ownershipSystem.removeOwner(smartObjectId, currentOwner);
      ownershipSystem.assignOwner(smartObjectId, owner);
    }

    locationSystem.saveLocation(smartObjectId, locationData);

    DeployableState.setIsValid(smartObjectId, true);
    DeployableState.setAnchoredAt(smartObjectId, block.timestamp);
  }

  /**
   * @dev unanchors a smart deployable
   * @param smartObjectId on-chain of the deployable
   */
  function unanchor(uint256 smartObjectId) public onlyActive context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    _setDeployableState(smartObjectId, previousState, State.UNANCHORED);

    // increment the inventory data version (this will make ALL previous inventory item data stale)
    // reset the used capacity to 0
    // TODO: the following is a candidate for hook logic and optimization
    uint256 classId = uint256(
      keccak256(abi.encodePacked(EntityRecord.getTenantId(smartObjectId), EntityRecord.getTypeId(smartObjectId)))
    );
    TagId inventorySystemTagId = TagIdLib.encode(
      TAG_TYPE_RESOURCE_RELATION,
      bytes30(ResourceId.unwrap(inventorySystem.toResourceId()))
    );
    if (EntityTagMap.getHasTag(classId, inventorySystemTagId)) {
      Inventory.setVersion(smartObjectId, Inventory.getVersion(smartObjectId) + 1);
      Inventory.setUsedCapacity(smartObjectId, 0);
    }
    // check if the deploybale is a smart gate and unlink it
    // TODO : move this to hook logic
    TagId gateSystemTagId = TagIdLib.encode(
      TAG_TYPE_RESOURCE_RELATION,
      bytes30(ResourceId.unwrap(smartGateSystem.toResourceId()))
    );
    if (EntityTagMap.getHasTag(classId, gateSystemTagId) && SmartGateLink.getIsLinked(smartObjectId)) {
      uint256 destinationGateId = SmartGateLink.getDestinationGateId(smartObjectId);
      smartGateSystem.unlinkGates(smartObjectId, destinationGateId);
    }

    // Remove ownership tracking through OwnershipSystem
    address owner = OwnershipHelper.getOwner(smartObjectId);
    ownershipSystem.removeOwner(smartObjectId, owner);

    locationSystem.saveLocation(smartObjectId, LocationData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));

    DeployableState.setIsValid(smartObjectId, false);
  }

  /**
   * @dev brings all smart deployables online
   */
  function globalPause() public context access(0) scope(0) {
    GlobalDeployableState.setIsPaused(true);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOffline(block.timestamp);
  }

  /**
   * @dev brings all smart deployables offline
   */
  function globalResume() public context access(0) scope(0) {
    GlobalDeployableState.setIsPaused(false);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOnline(block.timestamp);
  }

  /*******************************
   * INTERNAL DEPLOYABLE METHODS *
   *******************************/

  /**
   * @dev brings offline smart deployable (internal method)
   * @param smartObjectId on-chain of the deployable
   */
  function _bringOffline(uint256 smartObjectId, State previousState) internal {
    _setDeployableState(smartObjectId, previousState, State.ANCHORED);
  }

  /**
   * @dev internal method to set the state of a deployable
   * @param smartObjectId to update
   * @param previousState to set
   * @param currentState to set
   */
  function _setDeployableState(uint256 smartObjectId, State previousState, State currentState) internal {
    DeployableState.setPreviousState(smartObjectId, previousState);
    DeployableState.setCurrentState(smartObjectId, currentState);
    _updateBlockInfo(smartObjectId);
  }

  /**
   * @dev update block information for a given entity
   * @param smartObjectId to update
   */
  function _updateBlockInfo(uint256 smartObjectId) internal {
    DeployableState.setUpdatedBlockNumber(smartObjectId, block.number);
    DeployableState.setUpdatedBlockTime(smartObjectId, block.timestamp);
  }
}
