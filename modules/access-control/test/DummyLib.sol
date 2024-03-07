// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { DUMMY_SYSTEM_NAME } from "./constants.sol";

interface IDummy {
  function echoFoo(uint256 entityId) external;

  function echoBar(uint256 entityId, uint256 someNumber) external;
}

/**
 * @title Dummy Library (makes interacting with the underlying module cleaner)
 * @dev To preserve _msgSender() and other context-dependant properties, Library methods like those MUST be `internal`.
 * That way, the compiler is forced to inline the method's implementation in the contract they're imported into.
 */
library DummyLib {
  struct World {
    IBaseWorld iface;
    bytes14 namespace;
  }

  function echoFoo(World memory world, uint256 entityId) internal returns(uint256) {
    bytes memory returnData = world.iface.call(ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, world.namespace, DUMMY_SYSTEM_NAME)))),
      abi.encodeCall(IDummy.echoFoo,
        (entityId)
      )
    );
    return abi.decode(returnData, (uint256));
  }

  function echoBar(World memory world, uint256 entityId, uint256 someNumber) internal returns(bytes memory) {
    bytes memory returnData = world.iface.call(ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, world.namespace, DUMMY_SYSTEM_NAME)))),
      abi.encodeCall(IDummy.echoBar,
        (entityId, someNumber)
      )
    );
    return abi.decode(returnData, (bytes));

  }
}