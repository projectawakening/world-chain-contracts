// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_TABLE } from "@latticexyz/store/src/storeResourceTypes.sol";

import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { ERC721_SYSTEM_NAME } from "@eveworld/common-constants/src/constants.sol";

import { BALANCES_NAME, METADATA_NAME, OPERATOR_APPROVAL_NAME, OWNERS_NAME, TOKEN_APPROVAL_NAME, TOKEN_URI_NAME } from "./constants.sol";

library Utils {
  function balancesTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: BALANCES_NAME });
  }

  function metadataTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: METADATA_NAME });
  }

  function operatorApprovalTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: OPERATOR_APPROVAL_NAME });
  }

  function ownersTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: OWNERS_NAME });
  }

  function tokenApprovalTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: TOKEN_APPROVAL_NAME });
  }

  function tokenUriTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: TOKEN_URI_NAME });
  }

  function erc721SystemId(bytes14 namespace) internal pure returns (ResourceId systemId) {
    systemId = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: ERC721_SYSTEM_NAME });
  }
}
