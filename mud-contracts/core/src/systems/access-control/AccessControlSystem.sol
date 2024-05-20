// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";

import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";

import { Role } from "../../codegen/tables/Role.sol";
import { IAccessControlErrors } from "./IAccessControlErrors.sol";
import { ADMIN } from "./constants.sol";
import { Utils } from "./Utils.sol";

contract AccessControlSystem is EveSystem {
  using SmartDeployableUtils for bytes14;
  using Utils for bytes14;
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;

  function onlyAdminHook(bytes memory args) public {
    if (Role.get(ADMIN) != tx.origin) {
      revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, Role.get(ADMIN));
    }
  }

  function onlyOwnerHook(uint256 smartObjectId) public hookable(smartObjectId, _systemId()) {
    if (_initialMsgSender() != getOwner(smartObjectId)) {
      revert IAccessControlErrors.AccessControl_NoPermission(_initialMsgSender(), getOwner(smartObjectId));
    }
  }

  function createRole(bytes32 role, address roleAddress) public {
    Role.set(role, roleAddress);
  }

  function getOwner(uint256 smartObjectId) public returns (address owner) {
    owner = IERC721(DeployableTokenTable.getErc721Address(_namespace().deployableTokenTableId())).ownerOf(
      smartObjectId
    );
  }

  function _systemId() internal view returns (ResourceId) {
    return Utils.accessControlSystemId();
  }

  function _smartObjectFramework() internal view returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ iface: IBaseWorld(_world()), namespace: SMART_OBJECT_DEPLOYMENT_NAMESPACE });
  }
}
