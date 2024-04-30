// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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
    EntityRecordTable.set(_namespace().entityRecordTableId(), entityId, itemId, typeId, volume);
  }

  /**
   * @dev creates a new entity record
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * @param entityId we create an off-chain record for
   * @param name name of that entity
   * @param dappURL link to that entity's dApp URL
   * @param description description of that entity
   */
  function createEntityRecordOffchain(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(_namespace().entityRecordOffchainTableId(), entityId, name, dappURL, description);
  }

  /**
   * @dev creates a new entity record
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   *  make that Owner only too
   *  @param entityId we create an off-chain record for
   * @param name name of that entity
   * @param dappURL link to that entity's dApp URL
   * @param description description of that entity
   */
  function setEntityMetadata(
    uint256 entityId,
    string memory name,
    string memory dappURL,
    string memory description
  ) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(_namespace().entityRecordOffchainTableId(), entityId, name, dappURL, description);
  }

  /**
   * @dev changes that entity's name
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param name name of that entity
   */
  function setName(uint256 entityId, string memory name) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setName(_namespace().entityRecordOffchainTableId(), entityId, name);
  }

  /**
   * @dev changes that entity's dapp URL
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param dappURL link to that entity's dApp URL
   */
  function setDappURL(uint256 entityId, string memory dappURL) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setDappURL(_namespace().entityRecordOffchainTableId(), entityId, dappURL);
  }

  /**
   * @dev changes that entity's description
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param description description of that entity
   */
  function setDescription(uint256 entityId, string memory description) public hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setDescription(_namespace().entityRecordOffchainTableId(), entityId, description);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().entityRecordSystemId();
  }
}
