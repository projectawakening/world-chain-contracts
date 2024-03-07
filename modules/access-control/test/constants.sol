// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes14 constant DUMMY_MODULE_NAMESPACE = bytes14("dummyModule");
bytes16 constant DUMMY_MODULE_NAME = bytes16("dummyModule");

bytes14 constant DUMMY_NAMESPACE = bytes14("dummyNamespace");
bytes16 constant DUMMY_SYSTEM_NAME = bytes16("dummySystem");
// TODO: add some test to see if writing to tables inside a hook sub-routine works as intended
// bytes16 constant TEST_TABLE_NAME = bytes16("dummyTable");

ResourceId constant DUMMY_MODULE_NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, DUMMY_MODULE_NAMESPACE)));
// ResourceId constant TEST_TABLE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_TABLE, TEST_NAMESPACE, TEST_TABLE_NAME)));
ResourceId constant DUMMY_SYSTEM_ID = ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DUMMY_NAMESPACE, DUMMY_SYSTEM_NAME))));

//Constants for Entity
uint8 constant OBJECT = 1;
uint8 constant CLASS = 2;
