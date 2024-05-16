// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { OBJECT } from "@eve/frontier-smart-object-framework/src/constants.sol";
import { SMART_OBJECT_DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE, INVENTORY_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_CLASS_ID } from "@eve/common-constants/src/constants.sol";
import { SmartObjectLib } from "@eve/frontier-smart-object-framework/src/SmartObjectLib.sol";

import { LocationLib } from "../../location/LocationLib.sol";
import { IERC721Mintable } from "../../eve-erc721-puppet/IERC721Mintable.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";
import { GlobalDeployableState, GlobalDeployableStateData } from "../../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { DeployableFuelBalance, DeployableFuelBalanceData } from "../../../codegen/tables/DeployableFuelBalance.sol";

import { SmartDeployableErrors } from "../SmartDeployableErrors.sol";
import { State, SmartObjectData } from "../types.sol";
import { FUEL_DECIMALS } from "../constants.sol";
import { Utils } from "../Utils.sol";

contract SmartDeployable is EveSystem, SmartDeployableErrors {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;
  using LocationLib for LocationLib.World;

  // TODO: is `supportInterface` working properly here ?

  // TODO: The fuel logic will need to be decoupled from here at some point, once we have the right tooling to do so

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused(_namespace().globalStateTableId()) == false) {
      revert SmartDeployable_StateTransitionPaused();
    }
    _;
  }

  function registerDeployableToken(address tokenAddress) public {
    if (DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId()) != address(0)) {
      revert SmartDeployableERC721AlreadyInitialized();
    }
    DeployableTokenTable.setErc721Address(_namespace().deployableTokenTableId(), tokenAddress);
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
    uint256 fuelConsumptionPerMinuteInWei,
    uint256 fuelMaxCapacityInWei
  ) public hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (!(previousState == State.NULL || previousState == State.UNANCHORED)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    DeployableState.set(
      _namespace().deployableStateTableId(),
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
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      DeployableFuelBalanceData({
        fuelUnitVolume: fuelUnitVolumeInWei,
        fuelConsumptionPerMinute: fuelConsumptionPerMinuteInWei,
        fuelMaxCapacity: fuelMaxCapacityInWei,
        fuelAmount: 0,
        lastUpdatedAt: block.timestamp
      })
    );
    SmartObjectLib.World(IBaseWorld(_world()), SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEntity(entityId, OBJECT);
    SmartObjectLib.World(IBaseWorld(_world()), SMART_OBJECT_DEPLOYMENT_NAMESPACE).tagEntity(entityId, SMART_DEPLOYABLE_CLASS_ID);

    IERC721Mintable(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).mint(
      smartObjectData.owner,
      entityId
    );
    IERC721Mintable(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).setCid(
      entityId,
      smartObjectData.tokenURI
    );
  }

  /**
   * @dev destroys a smart deployable
   * @param entityId entityId
   */
  function destroyDeployable(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    _setDeployableState(entityId, previousState, State.DESTROYED);
    DeployableState.setIsValid(_namespace().deployableStateTableId(), entityId, false);
  }

  /**
   * @dev brings online smart deployable (must have been anchored first)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function bringOnline(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (previousState != State.ANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _updateFuel(entityId);
    if (DeployableFuelBalance.getFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId) == 0)
      revert SmartDeployable_NoFuel(entityId);
    _setDeployableState(entityId, previousState, State.ONLINE);
    DeployableFuelBalance.setLastUpdatedAt(_namespace().deployableFuelBalanceTableId(), entityId, block.timestamp);
  }

  /**
   * @dev brings offline smart deployable (must have been online first)
   * @param entityId entityId
   */
  function bringOffline(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
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
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (previousState != State.UNANCHORED) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }
    _setDeployableState(entityId, previousState, State.ANCHORED);
    _locationLib().saveLocation(entityId, locationData);
    DeployableState.setIsValid(_namespace().deployableStateTableId(), entityId, true);
    DeployableState.setAnchoredAt(_namespace().deployableStateTableId(), entityId, block.timestamp);
  }

  /**
   * @dev unanchors a smart deployable (must have been offline first)
   * @param entityId entityId
   */
  function unanchor(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) onlyActive {
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (!(previousState == State.ANCHORED || previousState == State.ONLINE)) {
      revert SmartDeployable_IncorrectState(entityId, previousState);
    }

    _setDeployableState(entityId, previousState, State.UNANCHORED);
    _locationLib().saveLocation(entityId, LocationTableData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));
    DeployableState.setIsValid(_namespace().deployableStateTableId(), entityId, false);
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalPause() public {
    GlobalDeployableState.setIsPaused(_namespace().globalStateTableId(), false);
    GlobalDeployableState.setUpdatedBlockNumber(_namespace().globalStateTableId(), block.number);
    GlobalDeployableState.setLastGlobalOffline(_namespace().globalStateTableId(), block.timestamp);
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalResume() public {
    GlobalDeployableState.setIsPaused(_namespace().globalStateTableId(), true);
    GlobalDeployableState.setUpdatedBlockNumber(_namespace().globalStateTableId(), block.number);
    GlobalDeployableState.setLastGlobalOnline(_namespace().globalStateTableId(), block.timestamp);
  }

  /**
   * @dev This is the rate of Fuel consumption of Onlined smart-deployables
   * WARNING: this will retroactively change the consumption rate of all smart deployables since they were last brought online.
   * do not tweak this too much. Right now this will have to do, or, ideally, we would need to update all fuel balances before changing this
   * TODO: needs to be only callable by admin
   * @param fuelConsumptionPerMinuteInWei global rate shared by all Smart Deployables (in Wei)
   */
  function setFuelConsumptionPerMinute(
    uint256 entityId,
    uint256 fuelConsumptionPerMinuteInWei
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    DeployableFuelBalance.setFuelConsumptionPerMinute(
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      fuelConsumptionPerMinuteInWei
    );
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
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    DeployableFuelBalance.setFuelMaxCapacity(_namespace().deployableFuelBalanceTableId(), entityId, capacityInWei);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * TODO: needs to make that function admin-only
   * @param entityId to deposit fuel to
   * @param unitAmount of fuel in full units
   */
  function depositFuel(
    uint256 entityId,
    uint256 unitAmount
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    _updateFuel(entityId);
    if (
      (
        ((DeployableFuelBalance.getFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId) +
          unitAmount *
          (10 ** FUEL_DECIMALS)) *
          DeployableFuelBalance.getFuelUnitVolume(_namespace().deployableFuelBalanceTableId(), entityId))
      ) /
        (10 ** FUEL_DECIMALS) >
      DeployableFuelBalance.getFuelMaxCapacity(_namespace().deployableFuelBalanceTableId(), entityId)
    ) {
      revert SmartDeployable_TooMuchFuelDeposited(entityId, unitAmount);
    }
    DeployableFuelBalance.setFuelAmount(
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      (DeployableFuelBalance.getFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId) +
        unitAmount *
        (10 ** FUEL_DECIMALS))
    );
    DeployableFuelBalance.setLastUpdatedAt(
      _namespace().deployableFuelBalanceTableId(),
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
  function withdrawFuel(
    uint256 entityId,
    uint256 unitAmount
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    _updateFuel(entityId);
    DeployableFuelBalance.setFuelAmount(
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      (_currentFuelAmount(entityId) - unitAmount * (10 ** FUEL_DECIMALS)) // will revert if underflow
    );
    DeployableFuelBalance.setLastUpdatedAt(
      _namespace().deployableFuelBalanceTableId(),
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
  function updateFuel(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) hookable(entityId, _systemId()) {
    _updateFuel(entityId);
  }

  /**
   * @dev view function to get an accurate read of the current amount of fuel
   * @param entityId looked up
   */
  function currentFuelAmount(
    uint256 entityId
  ) public onlyAssociatedModule(entityId, _systemId()) returns (uint256 amount) {
    return _currentFuelAmount(entityId) / (10 ** FUEL_DECIMALS);
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
    DeployableState.setPreviousState(_namespace().deployableStateTableId(), entityId, previousState);
    DeployableState.setCurrentState(_namespace().deployableStateTableId(), entityId, currentState);
    _updateBlockInfo(entityId);
  }

  /**
   * @dev update block information for a given entity
   * @param entityId to update
   */
  function _updateBlockInfo(uint256 entityId) internal {
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
  }

  /**
   * @dev internal method
   * @param entityId to update
   */
  function _updateFuel(uint256 entityId) internal {
    uint256 currentFuel = _currentFuelAmount(entityId);
    State previousState = DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId);
    if (currentFuel == 0 && (previousState == State.ONLINE)) {
      _bringOffline(entityId, previousState);
      DeployableFuelBalance.setFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId, 0);
    } else {
      DeployableFuelBalance.setFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId, currentFuel);
    }
    DeployableFuelBalance.setLastUpdatedAt(_namespace().deployableFuelBalanceTableId(), entityId, block.timestamp);
  }

  /**
   * internal method to look up current fuel amount from last updated state
   * @param entityId to lookup fuel amount for
   */
  function _currentFuelAmount(uint256 entityId) internal view returns (uint256 amount) {
    // since we make sure the last time we interacted with an entity was when we set it online, it's fine
    if (DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId) != State.ONLINE) {
      return DeployableFuelBalance.getFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId);
    }

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      _namespace().deployableFuelBalanceTableId(),
      entityId
    );
    // elapsed time in seconds, multiplied by consumption rate per second
    uint256 fuelConsumed = (block.timestamp - data.lastUpdatedAt) * (data.fuelConsumptionPerMinute / 60);
    fuelConsumed -= _globalOfflineFuelRefund(entityId);
    if (fuelConsumed >= data.fuelAmount) {
      return 0;
    }
    return data.fuelAmount - fuelConsumed;
  }

  /**
   * @dev assumes the servers don't go on/off/on/off/on very quickly (seriously please don't)
   * will refund the last globalOffline/globalOnline time elapsed
   * @param entityId to calculate the refund for
   */
  function _globalOfflineFuelRefund(uint256 entityId) internal view returns (uint256 refundAmount) {
    GlobalDeployableStateData memory globalData = GlobalDeployableState.get(_namespace().globalStateTableId());
    if (globalData.lastGlobalOffline == 0) return 0; // servers have never been shut down
    if (DeployableState.getCurrentState(_namespace().deployableStateTableId(), entityId) != State.ONLINE) return 0; // no refunds if it's not running

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(_namespace().deployableStateTableId(), entityId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spend online during server downtime
    return
      elapsedRefundTime *
      (DeployableFuelBalance.getFuelConsumptionPerMinute(_namespace().deployableFuelBalanceTableId(), entityId) / 60);
  }

  // TODO: this is kinda dirty.
  function _locationLib() internal view returns (LocationLib.World memory) {
    return LocationLib.World({ iface: IBaseWorld(_world()), namespace: LOCATION_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartDeployableSystemId();
  }
}
