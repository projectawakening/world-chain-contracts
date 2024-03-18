// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EveSystem } from "@eve/smart-object-framework/src/systems/internal/EveSystem.sol";

import { Utils } from "../utils.sol";
import { StaticDataTable } from "../codegen/tables/StaticDataTable.sol";
import { StaticDataGlobalTable } from "../codegen/tables/StaticDataGlobalTable.sol";

import { STATIC_DATA_SYSTEM_NAME } from "../constants.sol";

contract StaticData is EveSystem {
  using Utils for bytes14;

  /**
   * set a new Base URI for a SystemId (represents a class of object)
   * TODO: should we check if the targeted SystemID even points to something ?
   * @param systemId corresponds to the class targeted
   * @param baseURI the new base URI string
   */
  function setBaseURI(ResourceId systemId, string memory baseURI) public hookable(uint256(ResourceId.unwrap(systemId)), _systemId()) {
    StaticDataGlobalTable.setBaseURI(_namespace().staticDataGlobalTableId(), systemId, baseURI);
  }

  /**
   * set a new custom CID for an entity
   * @param entityId entityId of the in-game object
   * @param cid the new CID string
   */
  function setCid(uint256 entityId, string memory cid) public hookable(entityId, _systemId()) {
    StaticDataTable.setCid(_namespace().staticDataTableId(), entityId, cid);
  }

  /**
   * returns this contract's systemId
   */
  function _systemId() internal view returns (ResourceId) {
    return _namespace().getSystemId(STATIC_DATA_SYSTEM_NAME);
  }
}