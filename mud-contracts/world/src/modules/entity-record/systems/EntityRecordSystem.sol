// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { AccessModified } from "../../access/systems/AccessModified.sol";
import { Utils } from "../Utils.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../../codegen/tables/EntityRecordTable.sol";
import { EntityRecordOffchainTable, EntityRecordOffchainTableData } from "../../../codegen/tables/EntityRecordOffchainTable.sol";

contract EntityRecordSystem is AccessModified, EveSystem {
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
    uint256 typeId,
    uint256 volume
  ) public onlyAdmin hookable(entityId, _systemId()) {
    EntityRecordTable.set(entityId, itemId, typeId, volume, true);
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
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(entityId, name, dappURL, description);
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
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.set(entityId, name, dappURL, description);
  }

  /**
   * @dev changes that entity's name
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param name name of that entity
   */
  function setName(
    uint256 entityId,
    string memory name
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setName(entityId, name);
  }

  /**
   * @dev changes that entity's dapp URL
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param dappURL link to that entity's dApp URL
   */
  function setDappURL(
    uint256 entityId,
    string memory dappURL
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setDappURL(entityId, dappURL);
  }

  /**
   * @dev changes that entity's description
   * TODO: make sure that entityId exists in the SO-framework before going forward with this
   * also make it owner only ?
   * @param entityId we create an off-chain record for
   * @param description description of that entity
   */
  function setDescription(
    uint256 entityId,
    string memory description
  ) public onlyAdminOrObjectOwner(entityId) hookable(entityId, _systemId()) {
    EntityRecordOffchainTable.setDescription(entityId, description);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().entityRecordSystemId();
  }
}
