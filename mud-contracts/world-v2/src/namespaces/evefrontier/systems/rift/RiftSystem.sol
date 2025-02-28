// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Table imports
import { Rift } from "../../codegen/index.sol";

// Types
import { EntityRecordData } from "../entity-record/types.sol";
import { RIFT } from "../constants.sol";

// System imports
import { inventorySystem } from "../../codegen/systems/InventorySystemLib.sol";
import { crudeLiftSystem } from "../../codegen/systems/CrudeLiftSystemLib.sol";
import { smartAssemblySystem } from "../../codegen/systems/SmartAssemblySystemLib.sol";

// Constants
uint256 constant CRUDE_MATTER = 1;

contract RiftSystem is SmartObjectFramework {
  error RiftAlreadyExists();
  error RiftAlreadyCollapsed();

  // A rift is created with only an amount onchain
  // Location is "shielded" by the game server
  function createRift(uint256 riftId, uint256 crudeAmount) public context access(riftId) scope(getRiftClassId()) {
    if (Rift.getCreatedAt(riftId) != 0) revert RiftAlreadyExists();

    entitySystem.instantiate(getRiftClassId(), riftId, _callMsgSender());

    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 999, itemId: 999, volume: 999 });
    smartAssemblySystem.createSmartAssembly(riftId, RIFT, entityRecord);
    inventorySystem.setInventoryCapacity(riftId, crudeAmount);
    crudeLiftSystem.addCrude(riftId, crudeAmount);

    Rift.setCreatedAt(riftId, block.timestamp);
  }

  function destroyRift(uint256 riftId) public context access(riftId) scope(getRiftClassId()) {
    if (Rift.getCollapsedAt(riftId) != 0) revert RiftAlreadyCollapsed();

    crudeLiftSystem.clearCrude(riftId);

    Rift.setCollapsedAt(riftId, block.timestamp);
  }

  function getRiftClassId() public pure returns (uint256) {
    return uint256(bytes32("RIFT"));
  }
}
