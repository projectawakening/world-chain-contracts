// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";
import { RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

bytes14 constant MODULE_NAMESPACE = "eve-erc721-pup";
ResourceId constant MODULE_NAMESPACE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_NAMESPACE, MODULE_NAMESPACE))
);

bytes16 constant TOKEN_URI_NAME = "TokenURI";
bytes16 constant BALANCES_NAME = "Balances";
bytes16 constant METADATA_NAME = "Metadata";
bytes16 constant OPERATOR_APPROVAL_NAME = "OperatorApproval";
bytes16 constant TOKEN_APPROVAL_NAME = "TokenApproval";
bytes16 constant OWNERS_NAME = "Owners";

ResourceId constant ERC721_REGISTRY_TABLE_ID = ResourceId.wrap(
  bytes32(abi.encodePacked(RESOURCE_TABLE, MODULE_NAMESPACE, bytes16("ERC721Registry")))
);
