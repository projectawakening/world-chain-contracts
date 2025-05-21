// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { TagId, TagIdLib } from "@eveworld/smart-object-framework-v2/src/libs/TagId.sol";
import { EntityTagMap } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/EntityTagMap.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { TAG_TYPE_RESOURCE_RELATION } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/types.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Tenant, Initialize, DeployableState, DeployableStateData, CharactersByAccount, Location, LocationData, Inventory, InventoryItem, EntityRecord, SmartGateLink, NetworkNodeByAssembly, NetworkNode, NetworkNodeAssemblyLink, FuelConsumptionState } from "../../codegen/index.sol";

// Local namespace systems
import { LocationSystem } from "../location/LocationSystem.sol";
import { locationSystem } from "../../codegen/systems/LocationSystemLib.sol";
import { smartAssemblySystem } from "../../codegen/systems/SmartAssemblySystemLib.sol";
import { ownershipSystem } from "../../codegen/systems/OwnershipSystemLib.sol";
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { smartGateSystem } from "../../codegen/systems/SmartGateSystemLib.sol";
import { networkNodeSystem } from "../../codegen/systems/NetworkNodeSystemLib.sol";
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "./types.sol";
import { OwnershipHelper } from "../../libraries/OwnershipHelper.sol";
import { NETWORK_NODE } from "../constants.sol";
import { ObjectIdLib } from "../../libraries/ObjectIdLib.sol";

/**
 * @title DeployableSystem
 * @author CCP Games
 * DeployableSystem stores the deployable state of a smart object on-chain
 */
contract DeployableSystem is SmartObjectFramework {
  error Deployable_IncorrectState(uint256 smartObjectId, State currentState);
  error Deployable_InvalidObjectOwner(string message, address smartObjectOwner, uint256 smartObjectId);

  /**
   * @dev creates and anchors a deployable smart object
   * @param params struct containing all parameters for creating and anchoring a deployable
   * @param networkNodeId the network node id of the deployable
   */
  function createAndAnchor(
    CreateAndAnchorParams memory params,
    uint256 networkNodeId
  ) public context access(params.smartObjectId) {
    //TODO: this is not the correct way to use SOF, its a temporary  solution to allow deployables that does not have a proper class
    //If the smartObject is not part of any class, then default to the deployable class
    if (!Entity.getExists(params.smartObjectId)) {
      uint256 classId = ObjectIdLib.calculateSingletonId(Tenant.get(), params.entityRecordParams.typeId);
      entitySystem.instantiate(classId, params.smartObjectId, params.owner);
    }

    // Create the smart assembly object
    smartAssemblySystem.createAssembly(params.smartObjectId, params.assemblyType, params.entityRecordParams);

    createDeployable(params.smartObjectId, params.owner);

    anchor(params.smartObjectId, params.owner, params.locationData);

    // Handle network node connection if provided
    if (NetworkNode.getExists(networkNodeId)) {
      networkNodeSystem.connectAssembly(networkNodeId, params.smartObjectId);
    }
  }

  /**
   * @dev creates a new deployable smart object
   * @param smartObjectId id of the smart object
   * @param owner the owner of the smart object
   */
  function createDeployable(
    uint256 smartObjectId,
    address owner
  ) public context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.NULL) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
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
  }

  /**
   * @dev destroys a deployable smart object
   * @param smartObjectId id of the smart object
   */
  function destroyDeployable(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
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

    uint256 networkNodeId = NetworkNodeByAssembly.getNetworkNodeId(smartObjectId);
    if (NetworkNode.getExists(networkNodeId) && NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartObjectId)) {
      networkNodeSystem.releaseAssemblyEnergy(networkNodeId, smartObjectId); //release energy
      networkNodeSystem.disconnectAssembly(networkNodeId, smartObjectId);
    } else if (NetworkNode.getExists(smartObjectId)) {
      // For network nodes, stop burning fuel before bringing offline
      fuelSystem.stopBurn(smartObjectId); //stop fuel consumption
      networkNodeSystem.releaseNetworkNodeEnergy(smartObjectId); //release energy
      _handleNodeOffline(smartObjectId); //bring offline all connected assemblies
      networkNodeSystem.disconnectNetworkNode(smartObjectId);
    }

    _setDeployableState(smartObjectId, previousState, State.DESTROYED);
    DeployableState.setIsValid(smartObjectId, false);
  }

  /**
   * @dev brings a deployable smart object online
   * @param smartObjectId id of the smart object
   */
  function bringOnline(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.ANCHORED) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    //Check the energy requirement to bringOnline if the deployable is connected to a network node or if it is a network node
    uint256 networkNodeId = NetworkNodeByAssembly.getNetworkNodeId(smartObjectId);
    if (NetworkNode.getExists(networkNodeId) && NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartObjectId)) {
      fuelSystem.updateFuel(networkNodeId);
      networkNodeSystem.reserveAssemblyEnergy(networkNodeId, smartObjectId);
    } else if (NetworkNode.getExists(smartObjectId)) {
      // For network nodes, start burning fuel before bringing online
      if (!FuelConsumptionState.getBurnState(smartObjectId)) {
        fuelSystem.startBurn(smartObjectId);
      }
      networkNodeSystem.reserveNetworkNodeEnergy(smartObjectId);
    }
    _setDeployableState(smartObjectId, previousState, State.ONLINE);
  }

  /**
   * @dev brings a deployable smart object offline
   * @param smartObjectId id of the smart object
   */
  function bringOffline(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
    State previousState = DeployableState.getCurrentState(smartObjectId);
    if (previousState != State.ONLINE) {
      revert Deployable_IncorrectState(smartObjectId, previousState);
    }

    uint256 networkNodeId = NetworkNodeByAssembly.getNetworkNodeId(smartObjectId);
    if (NetworkNode.getExists(networkNodeId) && NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartObjectId)) {
      networkNodeSystem.releaseAssemblyEnergy(networkNodeId, smartObjectId);
    } else if (NetworkNode.getExists(smartObjectId)) {
      // For network nodes, stop burning fuel before bringing offline
      if (FuelConsumptionState.getBurnState(smartObjectId)) {
        fuelSystem.stopBurn(smartObjectId);
      }
      networkNodeSystem.releaseNetworkNodeEnergy(smartObjectId); //energy handling
      _handleNodeOffline(smartObjectId); //state handling
    }

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
  ) public context access(smartObjectId) scope(smartObjectId) {
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
  function unanchor(uint256 smartObjectId) public context access(smartObjectId) scope(smartObjectId) {
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

    locationSystem.saveLocation(smartObjectId, LocationData({ solarSystemId: 0, x: 0, y: 0, z: 0 }));

    uint256 networkNodeId = NetworkNodeByAssembly.getNetworkNodeId(smartObjectId);
    if (NetworkNode.getExists(networkNodeId) && NetworkNodeAssemblyLink.getIsConnected(networkNodeId, smartObjectId)) {
      networkNodeSystem.releaseAssemblyEnergy(networkNodeId, smartObjectId); //release energy
      networkNodeSystem.disconnectAssembly(networkNodeId, smartObjectId);
    } else if (NetworkNode.getExists(smartObjectId)) {
      // For network nodes, stop burning fuel before bringing offline
      fuelSystem.stopBurn(smartObjectId); //stop fuel consumption
      networkNodeSystem.releaseNetworkNodeEnergy(smartObjectId); //release energy
      _handleNodeOffline(smartObjectId); //bring offline all connected assemblies
      networkNodeSystem.disconnectNetworkNode(smartObjectId);
    }

    _setDeployableState(smartObjectId, previousState, State.UNANCHORED);
    DeployableState.setIsValid(smartObjectId, false);

    // Remove ownership tracking through OwnershipSystem
    address owner = OwnershipHelper.getOwner(smartObjectId);
    ownershipSystem.removeOwner(smartObjectId, owner);
  }

  function getDeployableClassId() public view returns (uint256) {
    return Initialize.get(deployableSystem.toResourceId());
  }

  /*******************************
   * INTERNAL DEPLOYABLE METHODS *
   *******************************/

  /**
   * @dev On network node offine, it should bring all connected assemblies offline
   * This function is defined here to avoid recursive calls
   * @param networkNodeId The smartObjectId of the Network Node
   */
  function _handleNodeOffline(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    //Bring all connected assemblies offline

    uint256[] memory connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);
    for (uint256 i = 0; i < connectedAssemblies.length; i++) {
      State previousState = DeployableState.getCurrentState(connectedAssemblies[i]);
      if (previousState == State.ONLINE) {
        _bringOffline(connectedAssemblies[i], previousState);
      }
    }
  }

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
