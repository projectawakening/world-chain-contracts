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
import { State } from "../types.sol";
import { Utils } from "../Utils.sol";
import { SmartDeployableErrors } from "../SmartDeployableErrors.sol";

contract SmartDeployable is EveSystem, SmartDeployableErrors {
  using WorldResourceIdInstance for ResourceId;
  using Utils for bytes14;
  using LocationLib for LocationLib.World;

  // TODO: is `supportInterface` working properly here ?

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
      DeployableStateData({ createdAt: block.timestamp, state: State.UNANCHORED, updatedBlockNumber: block.number })
    );
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
  }

  /**
   * @dev brings online smart deployable (must have been anchored first)
   * TODO: restrict this to entityIds that exist
   * @param entityId entityId
   */
  function bringOnline(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.ANCHORED) {
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.ONLINE);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
  }

  /**
   * @dev brings offline smart deployable (must have been online first)
   * @param entityId entityId
   */
  function bringOffline(uint256 entityId) public hookable(entityId, _systemId()) onlyState(entityId, State.ONLINE) {
    DeployableState.setState(_namespace().deployableStateTableId(), entityId, State.ANCHORED);
    DeployableState.setUpdatedBlockNumber(_namespace().deployableStateTableId(), entityId, block.number);
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
    _locationLib().saveLocation(entityId, LocationTableData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalOffline() public {
    GlobalDeployableState.set(
      _namespace().globalStateTableId(),
      GlobalDeployableStateData({ globalState: State.OFFLINE, updatedBlockNumber: block.number })
    );
  }

  /**
   * @dev brings all smart deployables offline (for admin use only)
   * TODO: actually needs to be made admin-only
   */
  function globalOnline() public {
    GlobalDeployableState.set(
      _namespace().globalStateTableId(),
      GlobalDeployableStateData({ globalState: State.ONLINE, updatedBlockNumber: block.number })
    );
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
