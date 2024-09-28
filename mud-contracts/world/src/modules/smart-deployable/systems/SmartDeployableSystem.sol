// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { LOCATION_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { AccessModified } from "../../access/systems/AccessModified.sol";
import { LocationLib } from "../../location/LocationLib.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";
import { GlobalDeployableState, GlobalDeployableStateData } from "../../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { DeployableFuelBalance, DeployableFuelBalanceData } from "../../../codegen/tables/DeployableFuelBalance.sol";
import { SmartAssemblyTable } from "../../../codegen/tables/SmartAssemblyTable.sol";
import { CharactersByAddressTable } from "../../../codegen/tables/CharactersByAddressTable.sol";

import { SmartDeployableErrors } from "../SmartDeployableErrors.sol";
import { State, SmartObjectData, SmartAssemblyType } from "../types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "../constants.sol";
import { Utils } from "../Utils.sol";

contract SmartDeployableSystem is AccessModified, EveSystem, SmartDeployableErrors {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using LocationLib for LocationLib.World;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused() == false) {
      revert SmartDeployable_StateTransitionPaused();
    }
    _;
  }

  function registerDeployableToken(
    address tokenAddress
  ) public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    if (DeployableTokenTable.getErc721Address() != address(0)) {
      revert SmartDeployableERC721AlreadyInitialized();
    }
    DeployableTokenTable.setErc721Address(tokenAddress);
  }

  /**
   * @dev registers a new smart deployable (must be "NULL" state)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function registerDeployable(
    uint256 entityId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolumeInWei,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacityInWei
  ) public onlyAdmin hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.NULL || previousState == State.UNANCHORED)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    // Revert if the fuelUnitConsumption interval is min 1
    if (fuelConsumptionIntervalInSeconds < 1) {
      revert SmartDeployable_InvalidFuelConsumptionInterval(entityId);
    }

    // revert if the given smart object owner is not a valid character
    // if (CharactersByAddressTable.get(smartObjectData.owner) == 0) {
    //   revert SmartDeployableErrors.SmartDeployable_InvalidObjectOwner(
    //     "SmartDeployableSystem: Smart Object owner is not a valid Smart Character",
    //     smartObjectData.owner,
    //     entityId
    //   );
    // }

    //Create a new deployable when its new
    if (previousState == State.NULL) {
      IERC721Mintable(DeployableTokenTable.getErc721Address()).mint(smartObjectData.owner, entityId);
      IERC721Mintable(DeployableTokenTable.getErc721Address()).setCid(entityId, smartObjectData.tokenURI);
    }

    DeployableState.set(
      entityId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: previousState,
        currentState: State.UNANCHORED,
        isValid: false,
        anchoredAt: 0,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
    DeployableFuelBalance.set(
      entityId,
      DeployableFuelBalanceData({
        fuelUnitVolume: fuelUnitVolumeInWei,
        fuelConsumptionPerMinute: fuelConsumptionIntervalInSeconds,
        fuelMaxCapacity: fuelMaxCapacityInWei,
        fuelAmount: 0,
        lastUpdatedAt: block.timestamp
      })
    );
  }

  /**
   * @dev sets the smart assembly type for a smart deployable
   * @param entityId of the smart assembly
   * @param smartAssemblyType of the type of smart assembly
   */
  function setSmartAssemblyType(
    uint256 entityId,
    SmartAssemblyType smartAssemblyType
  ) public onlyAdmin hookable(entityId, _systemId()) {
    SmartAssemblyTable.set(entityId, smartAssemblyType);
  }

  /**
   * @dev destroys a smart deployable
   * @param entityId entityId
   */
  function destroyDeployable(uint256 entityId) public onlyAdmin hookable(entityId, _systemId()) {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    _setDeployableState(entityId, previousState, State.DESTROYED);
    DeployableState.setIsValid(entityId, false);
  }

  /**
   * @dev brings online smart deployable (must have been anchored first)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function bringOnline(
    uint256 entityId
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.ANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _updateFuel(entityId);
    uint256 currentFuel = DeployableFuelBalance.getFuelAmount(entityId);
    if (currentFuel < 1) revert SmartDeployable_NoFuel(entityId);
    DeployableFuelBalance.setFuelAmount(entityId, currentFuel - ONE_UNIT_IN_WEI); //forces it to tick
    _setDeployableState(entityId, previousState, State.ONLINE);
    DeployableFuelBalance.setLastUpdatedAt(entityId, block.timestamp);
  }

  /**
   * @dev brings offline smart deployable (must have been online first)
   * @param entityId entityId
   */
  function bringOffline(
    uint256 entityId
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.ONLINE) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _updateFuel(entityId);
    _bringOffline(entityId, previousState);
  }

  /**
   * @dev anchors a smart deployable (must have been unanchored first)
   * @param entityId entityId
   */
  function anchor(
    uint256 entityId,
    LocationTableData memory locationData
  ) public onlyAdmin hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (previousState != State.UNANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _setDeployableState(entityId, previousState, State.ANCHORED);
    _locationLib().saveLocation(entityId, locationData);
    DeployableState.setIsValid(entityId, true);
    DeployableState.setAnchoredAt(entityId, block.timestamp);
  }

  /**
   * @dev unanchors a smart deployable (must have been offline first)
   * @param entityId entityId
   */
  function unanchor(uint256 entityId) public onlyAdmin hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    _setDeployableState(entityId, previousState, State.UNANCHORED);
    _locationLib().saveLocation(entityId, LocationTableData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));
    DeployableState.setIsValid(entityId, false);
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   */
  function globalPause() public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    GlobalDeployableState.setIsPaused(false);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOffline(block.timestamp);
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   */
  function globalResume() public onlyAdmin hookable(uint256(ResourceId.unwrap(_systemId())), _systemId()) {
    GlobalDeployableState.setIsPaused(true);
    GlobalDeployableState.setUpdatedBlockNumber(block.number);
    GlobalDeployableState.setLastGlobalOnline(block.timestamp);
  }

  /**
   * @dev This is the rate of Fuel consumption of Onlined smart-deployables
   * WARNING: this will retroactively change the consumption rate of all smart deployables since they were last brought online.
   * do not tweak this too much. Right now this will have to do, or, ideally, we would need to update all fuel balances before changing this
   * TODO: needs to be only callable by admin
   * @param fuelConsumptionIntervalInSeconds global rate shared by all Smart Deployables (in Wei)
   */
  function setFuelConsumptionPerMinute(
    uint256 entityId,
    uint256 fuelConsumptionIntervalInSeconds
  ) public onlyAdmin hookable(entityId, _systemId()) {
    DeployableFuelBalance.setFuelConsumptionPerMinute(entityId, fuelConsumptionIntervalInSeconds);
  }

  /**
   * @dev sets a new maximum fuel storage quantity for a Smart Deployable
   * TODO: needs to make that function admin-only
   * @param entityId to set the storage cap to
   * @param capacityInWei of max fuel (for now Fuel has 18 decimals like regular ERC20 balances)
   */
  function setFuelMaxCapacity(
    uint256 entityId,
    uint256 capacityInWei
  ) public onlyAdmin hookable(entityId, _systemId()) {
    DeployableFuelBalance.setFuelMaxCapacity(entityId, capacityInWei);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * TODO: needs to make that function admin-only
   * @param entityId to deposit fuel to
   * @param unitAmount of fuel in full units
   */
  function depositFuel(uint256 entityId, uint256 unitAmount) public onlyAdmin hookable(entityId, _systemId()) {
    _updateFuel(entityId);
    if (
      (
        ((DeployableFuelBalance.getFuelAmount(entityId) + unitAmount * ONE_UNIT_IN_WEI) *
          DeployableFuelBalance.getFuelUnitVolume(entityId))
      ) /
        ONE_UNIT_IN_WEI >
      DeployableFuelBalance.getFuelMaxCapacity(entityId)
    ) {
      revert SmartDeployable_TooMuchFuelDeposited(entityId, unitAmount);
    }
    DeployableFuelBalance.setFuelAmount(entityId, (_currentFuelAmount(entityId) + unitAmount * ONE_UNIT_IN_WEI));
    DeployableFuelBalance.setLastUpdatedAt(
      entityId,
      block.timestamp //UNIX time
    );
  }

  /**
   * @dev withdraws an amount of fuel for a Smart Deployable
   * Will revert if you try to withdraw more fuel than there's in it
   * TODO: needs to make that function admin-only
   * @param entityId to deposit fuel to
   * @param unitAmount of fuel (for now Fuel has 18 decimals like regular ERC20 balances)
   */
  function withdrawFuel(uint256 entityId, uint256 unitAmount) public onlyAdmin hookable(entityId, _systemId()) {
    _updateFuel(entityId);
    DeployableFuelBalance.setFuelAmount(
      entityId,
      (_currentFuelAmount(entityId) - unitAmount * ONE_UNIT_IN_WEI) // will revert if underflow
    );
    DeployableFuelBalance.setLastUpdatedAt(
      entityId,
      block.timestamp //UNIX time
    );
  }

  /**
   * @dev updates the amount of fuel on tables (allows event firing through table write op)
   * TODO: this should be a class-level hook that we attach to all and any function related to smart-deployables,
   * or that compose with it
   * @param entityId to update
   */
  function updateFuel(uint256 entityId) public {
    _updateFuel(entityId);
  }

  /**
   * @dev view function to get an accurate read of the current amount of fuel
   * @param entityId looked up
   */
  function currentFuelAmount(uint256 entityId) public view returns (uint256 amount) {
    return _currentFuelAmount(entityId) / ONE_UNIT_IN_WEI;
  }

  function currentFuelAmountInWei(uint256 entityId) public view returns (uint256 amount) {
    return _currentFuelAmount(entityId);
  }

  /********************
   * INTERNAL METHODS *
   ********************/
  /**
   * @dev brings offline smart deployable (internal method)
   * @param entityId entityId
   */
  function _bringOffline(uint256 entityId, State previousState) internal {
    _setDeployableState(entityId, previousState, State.ANCHORED);
  }

  /**
   * @dev internal method to set the state of a deployable
   * @param entityId to update
   * @param previousState to set
   * @param currentState to set
   */
  function _setDeployableState(uint256 entityId, State previousState, State currentState) internal {
    DeployableState.setPreviousState(entityId, previousState);
    DeployableState.setCurrentState(entityId, currentState);
    _updateBlockInfo(entityId);
  }

  /**
   * @dev update block information for a given entity
   * @param entityId to update
   */
  function _updateBlockInfo(uint256 entityId) internal {
    DeployableState.setUpdatedBlockNumber(entityId, block.number);
    DeployableState.setUpdatedBlockTime(entityId, block.timestamp);
  }

  /**
   * @dev internal method
   * @param entityId to update
   */
  function _updateFuel(uint256 entityId) internal {
    uint256 currentFuel = _currentFuelAmount(entityId);
    State previousState = DeployableState.getCurrentState(entityId);
    if (currentFuel == 0 && (previousState == State.ONLINE)) {
      _bringOffline(entityId, previousState);
      DeployableFuelBalance.setFuelAmount(entityId, 0);
    } else {
      DeployableFuelBalance.setFuelAmount(entityId, currentFuel);
    }
    DeployableFuelBalance.setLastUpdatedAt(entityId, block.timestamp);
  }

  /**
   * @dev Internal method to look up the current fuel amount for an entity from the last updated state.
   * @param entityId The ID of the entity to lookup fuel amount for.
   * @return amount The current fuel amount.
   */
  function _currentFuelAmount(uint256 entityId) internal view returns (uint256 amount) {
    // Check if the entity is not online. If it's not online, return the fuel amount directly.
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) {
      return DeployableFuelBalance.getFuelAmount(entityId);
    }

    // Fetch the fuel balance data for the entity.
    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(entityId);

    // For example:
    // OneFuelUnitConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
    // OneFuelUnitConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
    // OneFuelUnitConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
    uint256 oneFuelUnitConsumptionIntervalInSec = data.fuelConsumptionPerMinute;

    // Calculate the fuel consumed since the last update.
    // Multiply by ONE_UNIT_IN_WEI to maintain high precision and handle floating-point arithmetic.
    uint256 fuelConsumed = ((block.timestamp - data.lastUpdatedAt) * ONE_UNIT_IN_WEI) /
      oneFuelUnitConsumptionIntervalInSec;

    // Subtract any global offline fuel refund from the consumed fuel.
    fuelConsumed -= _globalOfflineFuelRefund(entityId);

    // If the consumed fuel is greater than or equal to the current fuel amount, return 0.
    if (fuelConsumed >= data.fuelAmount) {
      return 0;
    }

    // Return the remaining fuel amount.
    return data.fuelAmount - fuelConsumed;
  }

  /**
   * @dev assumes the servers don't go on/off/on/off/on very quickly (seriously please don't)
   * will refund the last globalOffline/globalOnline time elapsed
   * @param entityId to calculate the refund for
   */
  function _globalOfflineFuelRefund(uint256 entityId) internal view returns (uint256 refundAmount) {
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get();
    if (globalData.lastGlobalOffline == 0) return 0; // servers have never been shut down
    if (DeployableState.getCurrentState(entityId) != State.ONLINE) return 0; // no refunds if it's not running

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(entityId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spend online during server downtime
    return ((elapsedRefundTime * ONE_UNIT_IN_WEI) / (DeployableFuelBalance.getFuelConsumptionPerMinute(entityId)));
  }

  function _locationLib() internal view returns (LocationLib.World memory) {
    return LocationLib.World({ iface: IBaseWorld(_world()), namespace: LOCATION_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartDeployableSystemId();
  }
}
