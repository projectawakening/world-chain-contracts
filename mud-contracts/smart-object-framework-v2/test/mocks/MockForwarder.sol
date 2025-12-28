// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Bytes } from "@latticexyz/store/src/Bytes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { FunctionSelectors } from "@latticexyz/world/src/codegen/tables/FunctionSelectors.sol";

function createMockForwarder(address worldAddress, ResourceId systemId) returns (address mockForwarderEntryAddress) {
  IBaseWorld world = IBaseWorld(worldAddress);

  ResourceId namespaceId = WorldResourceIdInstance.getNamespaceId(systemId);
  if (!ResourceIds.getExists(namespaceId)) {
    world.registerNamespace(namespaceId);
  }

  MockForwarderSystem mockForwarderSystem = new MockForwarderSystem();
  world.registerSystem(systemId, mockForwarderSystem, true);

  MockForwarderEntry mockForwarderEntry = new MockForwarderEntry(worldAddress, systemId);
  return address(mockForwarderEntry);
}

/**
 * A system that calls another system, forwarding calldata, to simulate simple system-to-system calls
 */
contract MockForwarderSystem is System {
  function forwardCall(ResourceId systemId, bytes memory callData) external {
    IBaseWorld world = IBaseWorld(_world());
    bytes memory returnData = world.call(systemId, callData);

    // If the call was successful, return the return data
    assembly {
      return(add(returnData, 0x20), mload(returnData))
    }
  }
}

/**
 * MockForwarderEntry is called the same way as world, e.g. `IWorld(forwarderEntry).evefrontier__setTag(...)`
 * This helps simulate simple system-to-system calls without needing lots of mock contracts
 *
 * 0. MockForwarderEntry contract is not part of the world, and expects the SystemMock to be a public system
 * 1. MockForwarderEntry receives world selector + encoded args (e.g. `evefrontier__setTag` + args)
 * 2. MockForwarderEntry converts it to systemId + system calldata (e.g. "evefrontier:TagSystem", setTag selector + encoded args)
 * 3. MockForwarderEntry calls MockForwarderSystem with the systemId and calldata (via world)
 * 4. MockForwarderSystem calls the system with the systemId and calldata (this is the first system-to-system call)
 * 5. Both MockForwarderSystem and its Entry return what the called system does, which can have any format, so assembly is used
 */
contract MockForwarderEntry {
  error MockForwarderEntry_FunctionSelectorNotFound(bytes4 functionSelector);

  address internal worldAddress;
  ResourceId internal mockForwarderSystemId;

  constructor(address _worldAddress, ResourceId _mockForwarderSystemId) {
    worldAddress = _worldAddress;
    mockForwarderSystemId = _mockForwarderSystemId;

    StoreSwitch.setStoreAddress(worldAddress);
  }

  fallback() external payable {
    (ResourceId systemId, bytes4 systemFunctionSelector) = FunctionSelectors.get(msg.sig);

    if (ResourceId.unwrap(systemId) == 0) revert MockForwarderEntry_FunctionSelectorNotFound(msg.sig);

    // Replace function selector in the calldata with the system function selector
    bytes memory callData = Bytes.setBytes4(msg.data, 0, systemFunctionSelector);

    // Call the mock forwarder system
    bytes memory returnData = IBaseWorld(worldAddress).call(
      mockForwarderSystemId,
      abi.encodeWithSelector(MockForwarderSystem.forwardCall.selector, systemId, callData)
    );

    // If the call was successful, return the return data
    assembly {
      return(add(returnData, 0x20), mload(returnData))
    }
  }
}
