// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";

import { AccessModified } from "../../access-control/systems/AccessModified.sol";
import { Utils } from "../Utils.sol";
import { LocationTable, LocationTableData } from "../../../codegen/tables/LocationTable.sol";

contract LocationSystem is AccessModified, EveSystem {
  using Utils for bytes14;

  /**
   * set a new location for an entityId
   * TODO: add checks that the entity is properly registered and exists in the Smart Object Framework
   * TODO: add RBAC rules to prevent unauthorized actors to change those coordinates at will (no teleportation!)
   * @param entityId entity we set a new location for
   * @param location (solarsystemId, x,y,z) coordinates of the entityId
   */
  function saveLocation(uint256 entityId, LocationTableData memory location) public onlyAdmin() hookable(entityId, _systemId()) {
    LocationTable.set(_namespace().locationTableId(), entityId, location);
  }

  /**
   * returns this contract's systemId
   */
  function _systemId() internal view returns (ResourceId) {
    return _namespace().locationSystemId();
  }
}
