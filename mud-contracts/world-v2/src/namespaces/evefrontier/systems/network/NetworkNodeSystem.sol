// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { DeployableState, NetworkNode, NetworkNodeData, NetworkStructureConnection, AssemblyEnergyConfig, Initialize, EntityRecord, NetworkNodeByStructure } from "../../codegen/index.sol";

// Local namespace systems
import { deployableSystem } from "../../codegen/systems/DeployableSystemLib.sol";
import { fuelSystem } from "../../codegen/systems/FuelSystemLib.sol";
import { networkNodeSystem } from "../../codegen/systems/NetworkNodeSystemLib.sol";

// Types and parameters
import { State, CreateAndAnchorParams } from "../deployable/types.sol";
import { FuelParams } from "../fuel/types.sol";
import { NETWORK_NODE } from "../constants.sol";

contract NetworkNodeSystem is SmartObjectFramework {
  error NetworkNode_AlreadyExists(uint256 smartObjectId);
  error NetworkNode_DoesNotExist(uint256 smartObjectId);
  error NetworkNode_InsufficientEnergy(uint256 networkNodeId, uint256 required, uint256 available);
  error NetworkNode_NotOnline(uint256 networkNodeId);
  error NetworkNode_StructureNotConnected(uint256 networkNodeId, uint256 structureId);
  error NetworkNode_StructureAlreadyConnected(uint256 networkNodeId, uint256 structureId);
  error NetworkNode_NotConfigured(uint256 smartObjectId);

  /**
   * @notice Create and anchor a Network Node
   * @param params CreateAndAnchorDeployableParams
   * @param fuelParams Fuel configuration parameters
   * @param maxEnergyCapacity Maximum energy output capacity
   */
  function createAndAnchorNetworkNode(
    CreateAndAnchorParams memory params,
    FuelParams memory fuelParams,
    uint256 maxEnergyCapacity,
    uint256 currentProduction
  ) public context access(params.smartObjectId) scope(getNetworkNodeClassId()) {
    params.assemblyType = NETWORK_NODE;

    entitySystem.instantiate(getNetworkNodeClassId(), params.smartObjectId, params.owner);

    deployableSystem.createAndAnchor(params, params.smartObjectId);

    // Configure fuel parameters (only Network Nodes have fuel)
    fuelSystem.configureFuelParameters(params.smartObjectId, fuelParams);

    // Initialize Network Node data
    NetworkNode.set(
      params.smartObjectId,
      true, // exists
      maxEnergyCapacity, // maxEnergyCapacity
      currentProduction, // currentProduction
      0, // totalReservedEnergy (starts at 0)
      block.timestamp // lastUpdatedAt
    );

    NetworkNodeByStructure.set(params.smartObjectId, params.smartObjectId);
  }

  /**
   * @dev Connects a structure to a Network Node
   * @param networkNodeId The ID of the Network Node
   * @param structureId The ID of the structure to connect
   */
  function connectStructure(
    uint256 networkNodeId,
    uint256 structureId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    if (NetworkStructureConnection.getIsConnected(networkNodeId, structureId)) {
      revert NetworkNode_StructureAlreadyConnected(networkNodeId, structureId);
    }

    // Record the connection
    NetworkStructureConnection.set(
      networkNodeId,
      structureId,
      0, // reservedEnergy (set when brought online)
      true, // isConnected
      State.ANCHORED, // operationStatus
      block.timestamp, // connectedAt
      block.timestamp // lastEnergyUpdate
    );

    // Record for reverse lookup
    NetworkNodeByStructure.set(structureId, networkNodeId);
  }

  //TODO : Disconnect structure

  /**
   * @dev Handles a structure being brought online
   * @param networkNodeId The ID of the Network Node
   * @param structureId The ID of the structure
   */
  function onStructureOnline(
    uint256 networkNodeId,
    uint256 structureId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    // Get energy requirement for this structure type
    uint256 assemblyTypeId = EntityRecord.getTypeId(structureId);
    uint256 energyRequired = AssemblyEnergyConfig.getEnergyConstant(assemblyTypeId);

    // network node id and the structure id are the same to get the energy requirement of the network node
    if (networkNodeId != structureId) {
      if (!NetworkStructureConnection.getIsConnected(networkNodeId, structureId)) {
        revert NetworkNode_StructureNotConnected(networkNodeId, structureId);
      }
    }

    // Check if we have enough energy available
    uint256 currentReserved = NetworkNode.getTotalReservedEnergy(networkNodeId);
    uint256 maxCapacity = NetworkNode.getMaxEnergyCapacity(networkNodeId);

    if (currentReserved + energyRequired > maxCapacity) {
      revert NetworkNode_InsufficientEnergy(networkNodeId, energyRequired, maxCapacity - currentReserved);
    }

    // Update structure connection with reserved energy
    NetworkStructureConnection.setReservedEnergy(networkNodeId, structureId, energyRequired);
    NetworkStructureConnection.setOperationStatus(networkNodeId, structureId, State.ONLINE);
    NetworkStructureConnection.setLastEnergyUpdate(networkNodeId, structureId, block.timestamp);

    // Update total reserved energy
    NetworkNode.setTotalReservedEnergy(networkNodeId, currentReserved + energyRequired);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);
  }

  /**
   * @dev Handles a structure being brought offline
   * @param networkNodeId The ID of the Network Node
   * @param structureId The ID of the structure
   */
  function onStructureOffline(
    uint256 networkNodeId,
    uint256 structureId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    if (networkNodeId == structureId) {
      handleNodeOffline(networkNodeId);
    } else {
      if (!NetworkStructureConnection.getIsConnected(networkNodeId, structureId)) {
        revert NetworkNode_StructureNotConnected(networkNodeId, structureId);
      }

      // Get current reserved energy for this structure
      uint256 structureEnergy = NetworkStructureConnection.getReservedEnergy(networkNodeId, structureId);

      // Update structure connection
      NetworkStructureConnection.setReservedEnergy(networkNodeId, structureId, 0);
      NetworkStructureConnection.setOperationStatus(networkNodeId, structureId, State.ANCHORED);
      NetworkStructureConnection.setLastEnergyUpdate(networkNodeId, structureId, block.timestamp);

      // Update total reserved energy
      uint256 currentReserved = NetworkNode.getTotalReservedEnergy(networkNodeId);
      NetworkNode.setTotalReservedEnergy(networkNodeId, currentReserved - structureEnergy);
      NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);
    }
  }

  /**
   * @dev Handles Network Node going offline
   * @param networkNodeId The ID of the Network Node
   */
  function handleNodeOffline(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    // Reset total reserved energy
    NetworkNode.setTotalReservedEnergy(networkNodeId, 0);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

    // deployableSystem.bringOffline(networkNodeId);

    // TODO: Get all connected structures and bring them offline
  }

  function getNetworkNodeClassId() public view returns (uint256) {
    return Initialize.get(networkNodeSystem.toResourceId());
  }

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }
}
