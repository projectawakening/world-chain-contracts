// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { DelegationControl } from "@latticexyz/world/src/DelegationControl.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { PuppetRegistry } from "@latticexyz/world-modules/src/modules/puppet/tables/PuppetRegistry.sol";
import { PUPPET_TABLE_ID } from "@latticexyz/world-modules/src/modules/puppet/constants.sol";

contract DelegationControlSystem is DelegationControl {
  using WorldResourceIdInstance for ResourceId;

  mapping(ResourceId => address) public trustedForwarders;

  /**
   * @notice Verify the caller is the trusted forwarder
   * @dev Function to check if the caller is the trusted forwarder for the namespace
   * @param systemId The namespace to check the delegation
   * @return verified bool if the caller is the trusted forwarder
   */
  function verify(address, ResourceId systemId, bytes memory) public view returns (bool verified) {
    verified =
      (PuppetRegistry.get(PUPPET_TABLE_ID, systemId) == _msgSender()) ||
      (trustedForwarders[systemId.getNamespaceId()] == _msgSender());
  }

  /**
   * @notice Initialize the delegation for a namespace
   * @dev Function to add the admin address as the trusted forwarder for a namespace
   * @param namespaceId The namespace to initialize delegation
   * @param trustedForwarder The address who can initiate the call
   */
  function initDelegation(ResourceId namespaceId, address trustedForwarder) public {
    trustedForwarders[namespaceId] = trustedForwarder;
  }
}
