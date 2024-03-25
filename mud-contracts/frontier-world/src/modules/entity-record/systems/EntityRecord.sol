// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eve/frontier-smart-object-framework/src/SmartObjectLib.sol";

import { Utils } from "../Utils.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";

contract EntityRecord is EveSystem {
  using Utils for bytes14;

  /**
   * @dev TODO: make sure that entityId exists in the SO-framework before going forward with this
   * @param entityId entityId we create a record for
   * @param itemId itemId of that entity
   * @param typeId typeId of that entity
   * @param volume volume of that entity
   */
  function createEntityRecord(
    uint256 entityId,
    uint256 itemId,
    uint8 typeId,
    uint256 volume
  ) public hookable(entityId, _systemId()) {
    EntityRecordTable.set(_namespace().entityRecordTableTableId(), entityId, itemId, typeId, volume);
  }

  /**
   * @dev TODO: make sure that entityId exists in the SO-framework before going forward with this
   * @param entityId we create an off-chain record for 
   * @param name name of that entity
   * @param dappURL link to that entity's dApp URL 
   * @param description descriptino of that entity
   */
  function createEntityRecordOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(_namespace().entityRecordOffchainTableId(), entityId, name, dappURL, description);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().entityRecordSystemId();
  }
}
