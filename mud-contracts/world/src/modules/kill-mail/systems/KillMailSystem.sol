// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { KillMailLossType } from "../../../codegen/common.sol";
import { KillMailTable, KillMailTableData } from "../../../codegen/tables/KillMailTable.sol";
import { IKillMailErrors } from "../IKillMailErrors.sol";
import { AccessModified } from "../../access/systems/AccessModified.sol";
import { Utils } from "../Utils.sol";

contract KillMailSystem is AccessModified, EveSystem {
  using Utils for bytes14;

  function reportKill(
    uint256 killMailId,
    KillMailTableData memory killMailTableData
  ) public onlyAdmin hookable(killMailId, _systemId()) {
    if (KillMailTable.getKiller(killMailId) != address(0)) {
      revert IKillMailErrors.KillMail_AlreadyExists("KillMailSystem: Can't report an already reported kill");
    }

    KillMailTable.set(killMailId, killMailTableData);
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().killMailSystemId();
  }
}
