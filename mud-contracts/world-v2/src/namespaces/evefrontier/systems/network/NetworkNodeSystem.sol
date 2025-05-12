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
import { DeployableState, NetworkNode, NetworkNodeData, NetworkNodeAssemblyLink, AssemblyEnergyConfig, Initialize, EntityRecord, NetworkNodeByAssembly, NetworkNodeEnergyHistory } from "../../codegen/index.sol";

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
  error NetworkNode_AssemblyNotConnected(uint256 networkNodeId, uint256 assemblyId);
  error NetworkNode_AssemblyAlreadyConnected(uint256 networkNodeId, uint256 assemblyId);
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
      block.timestamp, // lastUpdatedAt
      new uint256[](0) // connectedAssemblies
    );
  }

  /**
   * @dev Connects a assembly to a Network Node
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly to connect
   */
  function connectAssembly(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    if (NetworkNodeAssemblyLink.getIsConnected(networkNodeId, assemblyId)) {
      revert NetworkNode_AssemblyAlreadyConnected(networkNodeId, assemblyId);
    }

    // Record the connection
    NetworkNodeAssemblyLink.set(
      networkNodeId,
      assemblyId,
      true, // isConnected
      block.timestamp // connectedAt
    );

    // Record for reverse lookup
    NetworkNodeByAssembly.set(assemblyId, networkNodeId);

    //Add assemblyId to the list of connected assemblies
    NetworkNode.pushConnectedAssemblies(networkNodeId, assemblyId);
  }

  //TODO : Disconnect assembly
  //When a assembly is disconnected from a network node, update the NetworkNode table and NetworkNodeAssemblyLink table

  /**
   * @dev Handles a assembly being brought online
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly
   */
  function onAssemblyOnline(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    uint256 assemblyTypeId;

    //If assembly is connected to a network node, get the energy requirement of the assembly
    if (NetworkNodeAssemblyLink.getIsConnected(networkNodeId, assemblyId)) {
      assemblyTypeId = EntityRecord.getTypeId(assemblyId);
    } else {
      //If assembly is not connected to a network node, get the energy requirement of the network node
      assemblyTypeId = EntityRecord.getTypeId(networkNodeId);
    }

    uint256 energyRequired = AssemblyEnergyConfig.getEnergyConstant(assemblyTypeId);

    // Check if we have enough energy available
    uint256 currentReserved = NetworkNode.getTotalReservedEnergy(networkNodeId);
    uint256 maxCapacity = NetworkNode.getMaxEnergyCapacity(networkNodeId);

    if (currentReserved + energyRequired > maxCapacity) {
      revert NetworkNode_InsufficientEnergy(networkNodeId, energyRequired, maxCapacity - currentReserved);
    }

    // Update total reserved energy
    NetworkNode.setTotalReservedEnergy(networkNodeId, currentReserved + energyRequired);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

    // Update energy history
    updateEnergyHistory(networkNodeId);
  }

  /**
   * @dev Update energy status by assembly on offline
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly
   */
  function onAssemblyOffline(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }
    _handleAssemblyOffline(networkNodeId, assemblyId);
  }

  /**
   * @dev Update energy status and diconnect all assemblies from the network node
   * @param networkNodeId The ID of the Network Node
   */
  function onNodeOffline(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    //make sure there is no connected assemblies
    uint256[] memory connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);
    for (uint256 i = 0; i < connectedAssemblies.length; i++) {
      _handleAssemblyOffline(networkNodeId, connectedAssemblies[i]); //release energy
    }

    _handleNodeOffline(networkNodeId);
  }

  /**
   * @dev Updates the energy history for a network node
   * @param networkNodeId The ID of the Network Node
   */
  function updateEnergyHistory(uint256 networkNodeId) internal {
    NetworkNodeEnergyHistory.set(networkNodeId, block.timestamp, NetworkNode.getTotalReservedEnergy(networkNodeId));
  }

  //INTERNAL FUNCTIONS
  /**
   * @dev Internal function to handle network node going offline
   * @param networkNodeId The ID of the Network Node
   */
  function _handleNodeOffline(uint256 networkNodeId) internal {
    // Reset total reserved energy
    NetworkNode.setEnergyProduced(networkNodeId, 0);
    NetworkNode.setTotalReservedEnergy(networkNodeId, 0);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

    // Update energy history
    updateEnergyHistory(networkNodeId);
  }

  /**
   * @dev Internal function to handle a single assembly going offline
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly
   */
  function _handleAssemblyOffline(uint256 networkNodeId, uint256 assemblyId) internal {
    uint256 assemblyTypeId = EntityRecord.getTypeId(assemblyId);
    uint256 releasedEnergy = AssemblyEnergyConfig.getEnergyConstant(assemblyTypeId);

    if (releasedEnergy > 0) {
      uint256 currentReserved = NetworkNode.getTotalReservedEnergy(networkNodeId);
      uint256 newReserved = currentReserved > releasedEnergy ? currentReserved - releasedEnergy : 0;

      NetworkNode.setTotalReservedEnergy(networkNodeId, newReserved);
      NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

      // Update energy history
      updateEnergyHistory(networkNodeId);
    }
  }

  function getNetworkNodeClassId() public view returns (uint256) {
    return Initialize.get(networkNodeSystem.toResourceId());
  }

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }
}
