// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "../../src/inherit/SmartObjectFramework.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { WorldContextProviderLib } from "@latticexyz/world/src/WorldContext.sol";
import { revertWithBytes } from "@latticexyz/world/src/revertWithBytes.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IWorldWithContext } from "../../src/IWorldWithContext.sol";
import { Id, IdLib } from "../../src/libs/Id.sol";
import { ENTITY_CLASS } from "../../src/types/entityTypes.sol";
import { Classes } from "../../src/namespaces/evefrontier/codegen/tables/Classes.sol";

import { TransientContext } from "./types.sol";

contract SystemMock is SmartObjectFramework {
  function classLevelScope(Id classId) public view scope(classId) returns (bool) {
    return true;
  }

  function objectLevelScope(Id objectId) public view scope(objectId) returns (bool) {
    return true;
  }

  function primaryCall() public payable context returns (bytes memory) {
    ResourceId systemId = _contextGuard();
    if (msg.sender != _world()) {
      // cannot receive payments from non-world sources (i.e. activity not delegated through the World contract)
      revert("Cannot receive payments from non-world sources");
    }

    bytes memory callData = abi.encodeCall(this.secondaryCall, ());
    return IWorldKernel(_world()).call(systemId, callData);
  }

  function secondaryCall() public context returns (TransientContext memory, TransientContext memory) {
    _contextGuard();
    // Class setting included to prevent this from being a view call, so that it can be included in the transient storage context tracking
    Id classId = IdLib.encode(ENTITY_CLASS, bytes30("TEST_CLASS"));
    Classes.set(classId, true, new bytes32[](0), new bytes32[](0));

    (ResourceId systemId1, bytes4 functionId1, address msgSender1, uint256 msgValue1) = IWorldWithContext(_world())
      .getWorldCallContext(1);
    (ResourceId systemId2, bytes4 functionId2, address msgSender2, uint256 msgValue2) = IWorldWithContext(_world())
      .getWorldCallContext(2);
    TransientContext memory transientContext1 = TransientContext(systemId1, functionId1, msgSender1, msgValue1);
    TransientContext memory transientContext2 = TransientContext(systemId2, functionId2, msgSender2, msgValue2);
    return (transientContext1, transientContext2);
  }

  function viewCall() public pure returns (bool) {
    return true;
  }

  function callFromWorldContextProviderLib() public returns (bytes memory) {
    ResourceId targetSystemId = WorldResourceIdLib.encode(
      RESOURCE_SYSTEM,
      bytes14("evefrontier"),
      bytes16("TaggedSystemMock")
    );
    address targetAddress = Systems.getSystem(targetSystemId);
    (bool success, bytes memory returnData) = WorldContextProviderLib.callWithContext(
      address(0xbadB0b),
      uint256(999),
      targetAddress,
      abi.encodeCall(this.primaryCall, ())
    );
    if (!success) revertWithBytes(returnData);
    return returnData;
  }

  function delegatecallFromWorldContextProviderLib() public returns (bytes memory) {
    ResourceId targetSystemId = WorldResourceIdLib.encode(
      RESOURCE_SYSTEM,
      bytes14("evefrontier"),
      bytes16("TaggedSystemMock")
    );
    address targetAddress = Systems.getSystem(targetSystemId);
    (bool success, bytes memory returnData) = WorldContextProviderLib.delegatecallWithContext(
      address(0xbadB0b),
      uint256(999),
      targetAddress,
      abi.encodeCall(this.primaryCall, ())
    );
    if (!success) revertWithBytes(returnData);
    return returnData;
  }
}
