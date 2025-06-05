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
import { SmartAssembly, DeployableState, NetworkNode, NetworkNodeData, NetworkNodeAssemblyLink, AssemblyEnergyConfig, Initialize, EntityRecord, NetworkNodeByAssembly, NetworkNodeEnergyHistory } from "../../codegen/index.sol";

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
  error NetworkNode_InvalidAssemblyType(uint256 networkNodeId, uint256 assemblyId);

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
      0, // currentProduction is 0 until its online
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

    if (NetworkNodeByAssembly.get(assemblyId) != 0) {
      revert NetworkNode_AssemblyAlreadyConnected(networkNodeId, assemblyId);
    }

    if (keccak256(abi.encodePacked(SmartAssembly.get(assemblyId))) == keccak256(abi.encodePacked(NETWORK_NODE))) {
      revert NetworkNode_InvalidAssemblyType(networkNodeId, assemblyId);
    }

    uint256 connectedAssemblyLength = NetworkNode.getConnectedAssemblies(networkNodeId).length;

    if (!NetworkNodeAssemblyLink.getIsConnected(networkNodeId, assemblyId)) {
      // Record the connection
      NetworkNodeAssemblyLink.set(
        networkNodeId,
        assemblyId,
        connectedAssemblyLength, // Index of the assembly in the connectedAssemblies array
        true, // isConnected
        block.timestamp // connectedAt
      );

      // Record for reverse lookup
      NetworkNodeByAssembly.set(assemblyId, networkNodeId);

      //Add assemblyId to the list of connected assemblies
      NetworkNode.pushConnectedAssemblies(networkNodeId, assemblyId);
    }
  }

  /**
   * @dev Connects a assembly to a Network Node
   * @param networkNodeId The ID of the Network Node
   * @param assemblyIds The IDs of the assemblies to connect.Note: This function can only process arrays of length upto 20.
   */
  function connectAssemblies(
    uint256 networkNodeId,
    uint256[] memory assemblyIds
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    uint256 connectedAssemblyLength = NetworkNode.getConnectedAssemblies(networkNodeId).length;

    for (uint256 i = 0; i < assemblyIds.length; i++) {
      uint256 assemblyId = assemblyIds[i];

      if (
        (NetworkNodeByAssembly.get(assemblyId) == 0) &&
        (!NetworkNodeAssemblyLink.getIsConnected(networkNodeId, assemblyId)) &&
        (keccak256(abi.encodePacked(SmartAssembly.get(assemblyId))) != keccak256(abi.encodePacked(NETWORK_NODE)))
      ) {
        // Record the connection
        NetworkNodeAssemblyLink.set(
          networkNodeId,
          assemblyId,
          connectedAssemblyLength + i, // Index of the assembly in the connectedAssemblies array
          true, // isConnected
          block.timestamp // connectedAt
        );

        // Record for reverse lookup
        NetworkNodeByAssembly.set(assemblyId, networkNodeId);
        NetworkNode.pushConnectedAssemblies(networkNodeId, assemblyId);
      }
    }
  }

  /**
   * @dev Disconnects a assembly from a Network Node
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly to disconnect
   */
  function disconnectAssembly(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    if (NetworkNodeAssemblyLink.getIsConnected(networkNodeId, assemblyId)) {
      uint256 assemblyIndex = NetworkNodeAssemblyLink.getConnectedAssemblyIndex(networkNodeId, assemblyId);
      uint256[] memory connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);

      uint256 lastElement = connectedAssemblies[connectedAssemblies.length - 1];
      NetworkNode.updateConnectedAssemblies(networkNodeId, assemblyIndex, lastElement);
      NetworkNode.popConnectedAssemblies(networkNodeId);
      NetworkNodeAssemblyLink.setConnectedAssemblyIndex(networkNodeId, lastElement, assemblyIndex);

      _deleteConnectedAssembly(networkNodeId, assemblyId);
    }
  }

  /**
   * @dev Disconnects all assemblies from a Network Node
   * @param networkNodeId The ID of the Network Node
   */
  function disconnectNetworkNode(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    uint256[] memory connectedAssemblies = NetworkNode.getConnectedAssemblies(networkNodeId);

    //TODO: find efficient way to do this
    for (uint256 i = 0; i < connectedAssemblies.length; i++) {
      uint256 assemblyId = connectedAssemblies[i];
      _deleteConnectedAssembly(networkNodeId, assemblyId);
    }

    NetworkNode.setConnectedAssemblies(networkNodeId, new uint256[](0));
  }

  /**
   * @dev Handles a assembly being brought online
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly
   */
  function reserveAssemblyEnergy(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    uint256 assemblyTypeId = EntityRecord.getTypeId(assemblyId);
    _reserveEnergy(networkNodeId, assemblyTypeId);
  }

  /**
   * @dev Handles a network node being brought online
   * @param networkNodeId SmartObjectId of the Network Node
   */
  function reserveNetworkNodeEnergy(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    NetworkNode.setEnergyProduced(networkNodeId, NetworkNode.getMaxEnergyCapacity(networkNodeId));
    uint256 assemblyTypeId = EntityRecord.getTypeId(networkNodeId);
    _reserveEnergy(networkNodeId, assemblyTypeId);
  }

  /**
   * @dev Update energy status by assembly on offline
   * @param networkNodeId The ID of the Network Node
   * @param assemblyId The ID of the assembly
   */
  function releaseAssemblyEnergy(
    uint256 networkNodeId,
    uint256 assemblyId
  ) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }
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

  /**
   * @dev Update energy status and release energy
   * @param networkNodeId The ID of the Network Node
   */
  function releaseNetworkNodeEnergy(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    if (!NetworkNode.getExists(networkNodeId)) {
      revert NetworkNode_DoesNotExist(networkNodeId);
    }

    // Reset total reserved energy
    NetworkNode.setEnergyProduced(networkNodeId, 0);
    NetworkNode.setTotalReservedEnergy(networkNodeId, 0);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

    // Update energy history
    updateEnergyHistory(networkNodeId);
  }

  /**
   * @dev Updates the energy history for a network node
   * @param networkNodeId SmartObjectId of the Network Node
   * TODO: change access control to only allow admin or deployable system
   */
  function updateEnergyHistory(uint256 networkNodeId) public context access(networkNodeId) scope(networkNodeId) {
    NetworkNodeEnergyHistory.set(networkNodeId, block.timestamp, NetworkNode.getTotalReservedEnergy(networkNodeId));
  }

  function getNetworkNodeClassId() public view returns (uint256) {
    return Initialize.get(networkNodeSystem.toResourceId());
  }

  function getWorld() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }

  /*******************************
   * INTERNAL FUNCTIONS *
   *******************************/
  /**
   * @dev Handles a assembly being brought online
   * @param networkNodeId SmartObjectId of the Network Node
   * @param assemblyId SmartObjectId of the assembly
   */
  function _reserveEnergy(uint256 networkNodeId, uint256 assemblyId) internal {
    uint256 energyRequired = AssemblyEnergyConfig.getEnergyConstant(assemblyId);

    // Check if we have enough energy available
    uint256 currentReserved = NetworkNode.getTotalReservedEnergy(networkNodeId);
    uint256 currentProduction = NetworkNode.getEnergyProduced(networkNodeId);

    if (currentReserved + energyRequired > currentProduction) {
      uint256 energyAvailable = currentProduction == 0 ? 0 : currentProduction - currentReserved;
      revert NetworkNode_InsufficientEnergy(networkNodeId, energyRequired, energyAvailable);
    }

    // Update total reserved energy
    NetworkNode.setTotalReservedEnergy(networkNodeId, currentReserved + energyRequired);
    NetworkNode.setLastUpdatedAt(networkNodeId, block.timestamp);

    // Update energy history
    updateEnergyHistory(networkNodeId);
  }

  function _deleteConnectedAssembly(uint256 networkNodeId, uint256 assemblyId) internal {
    NetworkNodeAssemblyLink.deleteRecord(networkNodeId, assemblyId);
    NetworkNodeByAssembly.deleteRecord(assemblyId);
  }
}
