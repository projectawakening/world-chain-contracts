// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceAccess } from "@latticexyz/world/src/codegen/tables/ResourceAccess.sol";

import { IWorldWithEntryContext } from "../../../IWorldWithEntryContext.sol";
import { AccessRole, AccessRolePerSys, AccessEnforcement } from "../../../codegen/index.sol";

import { IAccessSystemErrors } from "../interfaces/IAccessSystemErrors.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";

contract AccessSystem is EveSystem {
  function setAccessListByRole(bytes32 accessRoleId, address[] memory accessList) public {
    // we are reserving "OWNER" for the ERC721 owner accounts (ownership defined in the ERC721 tables, not here)
    if (accessRoleId == bytes32("OWNER")) {
      revert IAccessSystemErrors.AccessSystem_InvalidRoleId();
    }
    // only account granted access to the AccessRole table can sucessfully call this function
    if (!ResourceAccess.get(AccessRole._tableId, IWorldWithEntryContext(_world()).initialMsgSender())) {
      revert IAccessSystemErrors.AccessSystem_AccessConfigDenied();
    }
    AccessRole.set(accessRoleId, accessList);
  }

  function setAccessListPerSystemByRole(ResourceId systemId, bytes32 accessRoleId, address[] memory accessList) public {
    // we are reserving "OWNER" for the ERC721 owner accounts (ownership defined in the ERC721 tables, not here)
    if (accessRoleId == bytes32("OWNER")) {
      revert IAccessSystemErrors.AccessSystem_InvalidRoleId();
    }
    // only accounts granted access to the AccessRolePerSys table can sucessfully call this function
    if (!ResourceAccess.get(AccessRolePerSys._tableId, IWorldWithEntryContext(_world()).initialMsgSender())) {
      revert IAccessSystemErrors.AccessSystem_AccessConfigDenied();
    }
    AccessRolePerSys.set(systemId, accessRoleId, accessList);
  }

  function setAccessEnforcement(bytes32 target, bool isEnforced) public {
    // only accounts granted access to the AccessEnforcement table can sucessfully call this function
    if (!ResourceAccess.get(AccessEnforcement._tableId, IWorldWithEntryContext(_world()).initialMsgSender())) {
      revert IAccessSystemErrors.AccessSystem_AccessConfigDenied();
    }
    AccessEnforcement.set(target, isEnforced);
  }
}
