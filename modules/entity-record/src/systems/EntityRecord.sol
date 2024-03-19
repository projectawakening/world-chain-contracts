// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eve/smart-object-framework/src/SmartObjectLib.sol";

import { Utils } from "../utils.sol";
import { EntityRecordTable, EntityRecordTableData } from "../codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../codegen/tables/EntityRecordOffchainTable.sol";


contract EntityRecord is EveSystem {
  using Utils for bytes14;

  function createEntityRecord(uint256 entityId, uint256 itemId, uint8 typeId, uint256 volume) public hookable(entityId, _systemId()) {
    EntityRecordTable.set(
      _namespace().entityRecordTableTableId(),
      entityId,
      itemId,
      typeId,
      volume
    );
  }

  function createEntityRecordOffchain(uint256 entityId, string memory name, string memory dappURL, string memory description) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(
      _namespace().entityRecordOffchainTableId(),
      entityId,
      name,
      dappURL,
      description
    );
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().entityRecordSystemId();
  }
}