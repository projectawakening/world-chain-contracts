// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE, LOCATION_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { LocationLib } from "../../location/LocationLib.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../../codegen/tables/GlobalDeployableState.sol";
import { DeployableState, DeployableStateData } from "../../../codegen/tables/DeployableState.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { DeployableFuelBalance, DeployableFuelBalanceData } from "../../../codegen/tables/DeployableFuelBalance.sol";
import { State } from "../types.sol";
import { Utils } from "../Utils.sol";
import { SmartDeployableErrors } from "../SmartDeployableErrors.sol";

import { FUEL_DECIMALS, DEFAULT_DEPLOYABLE_FUEL_STORAGE } from "../constants.sol";

contract SmartDeployable is EveSystem, SmartDeployableErrors {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using LocationLib for LocationLib.World;

  // TODO: is `supportInterface` working properly here ?

  // TODO: The fuel logic will need to be decoupled from here at some point, once we have the right tooling to do so

  /**
   * modifier to enforce a certain state to be had by an entity
   * @param entityId entityId of the object we test against
   * @param reqState required State
   */
  modifier onlyState(uint256 entityId, State reqState) {
    if (GlobalDeployableState.getGlobalState(_namespace().globalStateTableId()) == State.OFFLINE) {
      revert SmartDeployable_GloballyOffline();
    } else if (
      uint256(DeployableState.getState(_namespace().deployableStateTableId(), entityId)) != uint256(reqState)
    ) {
      revert SmartDeployable_incorrectState(
        entityId,
        reqState,
        DeployableState.getState(_namespace().deployableStateTableId(), entityId)
      );
    }
    _;
  }

  /**
   * @dev registers a new smart deployable (must be "NULL" state)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function registerDeployable(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.NULL) {
    DeployableState.set(
      _namespace().deployableStateTableId(),
      entityId,
      DeployableStateData({
        createdAt: block.timestamp,
        state: State.UNANCHORED,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
    DeployableFuelBalance.setFuelMaxCapacity(_namespace().deployableFuelBalanceTableId(), entityId, DEFAULT_DEPLOYABLE_FUEL_STORAGE);
    DeployableFuelBalance.setLastUpdatedAt(_namespace().deployableFuelBalanceTableId(), entityId, block.timestamp);
  }

  /**
   * @dev destroys a smart deployable
   * @param entityId entityId
   */
  function destroyDeployable(
    uint256 entityId
  ) public hookable(entityId, _systemId()) onlyState(entityId, State.UNANCHORED) {
    // TODO: figure out how to delete inventory in the case of smart storage units
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.DESTROYED);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
  }

  /**
   * @dev brings online smart deployable (must have been anchored first)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function bringOnline(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.ANCHORED) {
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.ONLINE);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
  }

  /**
   * @dev brings offline smart deployable (must have been online first)
   * @param entityId entityId
   */
  function bringOffline(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.ONLINE) {
    _updateFuel(entityId);
    _bringOffline(entityId);
  }

  /**
   * @dev anchors a smart deployable (must have been unanchored first)
   * @param entityId entityId
   */
  function anchor(
    uint256 entityId,
    LocationTableData memory locationData
  ) public hookable(entityId, _systemId()) onlyState(entityId, State.UNANCHORED) {
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.ANCHORED);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
    _locationLib().saveLocation(entityId, locationData);
  }

  /**
   * @dev unanchors a smart deployable (must have been offline first)
   * @param entityId entityId
   */
  function unanchor(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.ANCHORED) {
    // TODO: figure out how to delete inventory in the case of smart storage units
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.UNANCHORED);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
    _locationLib().saveLocation(entityId, LocationTableData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalOffline() public {
    GlobalDeployableState.setGlobalState(_namespace().globalStateTableId(), State.OFFLINE);
    GlobalDeployableState.setUpdatedBlockNumber(_namespace().globalStateTableId(), block.number);
    GlobalDeployableState.setLastGlobalOffline(_namespace().globalStateTableId(), block.timestamp);
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalOnline() public {
    GlobalDeployableState.setGlobalState(_namespace().globalStateTableId(), State.ONLINE);
    GlobalDeployableState.setUpdatedBlockNumber(_namespace().globalStateTableId(), block.number);
    GlobalDeployableState.setLastGlobalOnline(_namespace().globalStateTableId(), block.timestamp);
  }

  /**
   * @dev This is the rate of Fuel consumption of Onlined smart-deployables
   * WARNING: this will retroactively change the consumption rate of all smart deployables since they were last brought online.
   * do not tweak this too much. Right now this will have to do, or, ideally, we would need to update all fuel balances before changing this
   * TODO: needs to be only callable by admin
   * @param fuelConsumptionPerMinute global rate shared by all Smart Deployables
   */
  function setFuelConsumptionPerMinute(uint256 fuelConsumptionPerMinute) public {
    GlobalDeployableState.setFuelConsumptionPerMinute(_namespace().globalStateTableId(), fuelConsumptionPerMinute);
  }

  /**
   * @dev sets a new maximum fuel storage quantity for a Smart Deployable
   * TODO: needs to make that function admin-only
   * @param entityId to set the storage cap to
   * @param amount of max fuel (for now Fuel has 18 decimals like regular ERC20 balances)
   */
  function setFuelMaxCapacity(uint256 entityId, uint256 amount) public {
    DeployableFuelBalance.setFuelMaxCapacity(_namespace().deployableFuelBalanceTableId(), entityId, amount);
  }

  /**
   * @dev deposit an amount of fuel for a Smart Deployable
   * TODO: needs to make that function admin-only
   * @param entityId to deposit fuel to
   * @param amount of fuel (for now Fuel has 18 decimals like regular ERC20 balances)
   */
  function depositFuel(uint256 entityId, uint256 amount) public {
    _updateFuel(entityId);
    if(DeployableFuelBalance.getFuelAmount(
        _namespace().deployableFuelBalanceTableId(),
        entityId) + amount 
        >
        DeployableFuelBalance.getFuelMaxCapacity(
        _namespace().deployableFuelBalanceTableId(),
        entityId
      )) {
      revert SmartDeployable_TooMuchFuelDeposited(entityId, amount);
    }
    DeployableFuelBalance.setFuelAmount(
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      _currentFuelAmount(entityId) + amount
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
   * @param amount of fuel (for now Fuel has 18 decimals like regular ERC20 balances)
   */
  function withdrawFuel(uint256 entityId, uint256 amount) public {
    _updateFuel(entityId);
    DeployableFuelBalance.setFuelAmount(
      _namespace().deployableFuelBalanceTableId(),
      entityId,
      _currentFuelAmount(entityId) - amount // will revert if underflow
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
  function updateFuel(uint256 entityId) public {
    _updateFuel(entityId);
  }

  /**
   * @dev view function to get an accurate read of the current amount of fuel
   * @param entityId looked up
   */
  function currentFuelAmount(uint256 entityId) public view returns (uint256 amount) {
    return _currentFuelAmount(entityId);
  }

  /********************
   * INTERNAL METHODS *
   ********************/

  /**
   * @dev brings offline smart deployable (internal method)
   * @param entityId entityId
   */
  function _bringOffline(uint256 entityId) internal {
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.ANCHORED);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
    DeployableState.setUpdatedBlockTime(_namespace().deployableStateTableId(), entityId, block.timestamp);
  }

  /**
   * @dev internal method
   * @param entityId to update
   */
  function _updateFuel(uint256 entityId) internal {
    uint256 currentFuel = _currentFuelAmount(entityId);

    if (
      currentFuel == 0 && (DeployableState.getState(_namespace().deployableStateTableId(), entityId) == State.ONLINE)
    ) {
      _bringOffline(entityId);
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
    if (DeployableState.getState(_namespace().deployableStateTableId(), entityId) != State.ONLINE) {
      return DeployableFuelBalance.getFuelAmount(_namespace().deployableFuelBalanceTableId(), entityId);
    }

    DeployableFuelBalanceData memory data = DeployableFuelBalance.get(
      _namespace().deployableFuelBalanceTableId(),
      entityId
    );
    uint256 fuelCPM = GlobalDeployableState.getFuelConsumptionPerMinute(_namespace().globalStateTableId());
    // elapsed time in seconds, multiplied by consumption rate per second
    uint256 fuelConsumed = (block.timestamp - data.lastUpdatedAt) * (fuelCPM / 60);
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
    if (DeployableState.getState(_namespace().deployableStateTableId(), entityId) != State.ONLINE) return 0; // no refunds if it's not running

    uint256 bringOnlineTimestamp = DeployableState.getUpdatedBlockTime(_namespace().deployableStateTableId(), entityId);
    if (bringOnlineTimestamp < globalData.lastGlobalOffline) bringOnlineTimestamp = globalData.lastGlobalOffline;

    uint256 lastGlobalOnline = globalData.lastGlobalOnline;
    if (lastGlobalOnline < globalData.lastGlobalOffline) lastGlobalOnline = block.timestamp; // still ongoing

    uint256 elapsedRefundTime = lastGlobalOnline - bringOnlineTimestamp; // amount of time spend online during server downtime
    return
      elapsedRefundTime * (GlobalDeployableState.getFuelConsumptionPerMinute(_namespace().globalStateTableId()) / 60);
  }

  // TODO: this is kinda dirty.
  function _locationLib() internal view returns (LocationLib.World memory) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(LOCATION_DEPLOYMENT_NAMESPACE))) {
      return LocationLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
    } else return LocationLib.World({ iface: IBaseWorld(_world()), namespace: LOCATION_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartDeployableSystemId();
  }
}
