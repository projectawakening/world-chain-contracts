// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes14 constant NAMESPACE = bytes14("deployable");
bytes16 constant MODULE_NAME = bytes16("smartDeployable");
bytes16 constant SYSTEM_NAME = bytes16("system");
bytes16 constant TABLE_NAME = bytes16("table");

ResourceId constant NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, NAMESPACE)));
ResourceId constant TABLE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_TABLE, NAMESPACE, TABLE_NAME)));
ResourceId constant SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, SYSTEM_NAME))));

// Constants for Hook Contract
bytes16 constant HOOK_SYSTEM_NAME = bytes16("hookSystem");
ResourceId constant HOOK_SYSTEM_ID = ResourceId.wrap(
  (bytes32(abi.encodePacked(RESOURCE_SYSTEM, NAMESPACE, HOOK_SYSTEM_NAME)))
);

//Constants for Entity
uint8 constant OBJECT = 1;
uint8 constant CLASS = 2;
