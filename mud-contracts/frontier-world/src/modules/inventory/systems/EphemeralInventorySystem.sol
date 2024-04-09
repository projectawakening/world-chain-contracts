// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { EphemeralInventoryTable } from "../../../codegen/tables/EphemeralInventoryTable.sol";
import { IInventoryErrors } from "../IInventoryErrors.sol";
import { Utils } from "../Utils.sol";
import { InventoryItem } from "../../types.sol";

contract EphemeralInventorySystem is EveSystem {
  using Utils for bytes14;

  function setEphemeralInventoryCapacity(
    uint256 smartObjectId,
    address owner,
    uint256 ephemeralStorageCapacity
  ) public {
    if (ephemeralStorageCapacity == 0) {
      revert IInventoryErrors.EphemeralInventory_InvalidCapacity(
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      );
    }
    EphemeralInventoryTable.setCapacity(
      _namespace().ephemeralInventoryTableId(),
      smartObjectId,
      owner,
      ephemeralStorageCapacity
    );
  }

  function depositToEphemeralInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to deposit items to the inventory
  }

  function withdrawFromEphemeralInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    //Implement the logic to withdraw items from the inventory
  }

  function interact(uint256 smartObjectId, bytes memory interactionData) public {
    //Implement the logic to interact with the inventory
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().ephemeralInventorySystemId();
  }
}
