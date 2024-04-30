// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import "./constants.sol";

library Utils {
  using WorldResourceIdInstance for ResourceId;

  function getSystemId(bytes14 namespace, bytes16 name) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: name });
  }

  function inventorySystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: namespace, name: INVENTORY_SYSTEM_NAME });
  }

  function ephemeralInventorySystemId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: namespace,
        name: EPHEMERAL_INVENTORY_SYSTEM_NAME
      });
  }

  function inventoryTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: INVENTORY_TABLE_NAME });
  }

  function inventoryItemTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: INVENTORY_ITEM_TABLE_NAME });
  }

  function ephemeralInventoryTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: EPHEMERAL_INVENTORY_TABLE_NAME });
  }

  function ephemeralInventoryItemTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_TABLE,
        namespace: namespace,
        name: EPHEMERAL_INVENTORY_ITEM_TABLE_NAME
      });
  }

  function itemTransferTableId(bytes14 namespace) internal pure returns (ResourceId) {
    return WorldResourceIdLib.encode({ typeId: RESOURCE_TABLE, namespace: namespace, name: ITEM_TRANSFER_TABLE_NAME });
  }
}
