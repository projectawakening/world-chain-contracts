// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IWorldWithEntryContext } from "../../../IWorldWithEntryContext.sol";
import { ResourceAccess } from "@latticexyz/world/src/codegen/tables/ResourceAccess.sol";

import { IERC721 } from "../../eve-erc721-puppet/IERC721.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";

import { AccessRole, AccessRolePerSys, AccessEnforcement } from "../../../codegen/index.sol";

import { IAccessSystemErrors } from "../interfaces/IAccessSystemErrors.sol";
import { ADMIN, APPROVED } from "../constants.sol";

contract AccessModified is System {
  using SmartDeployableUtils for bytes14;

  modifier onlyAdmin() {
    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListAdmin = AccessRole.get(ADMIN);
      bool access;
      for (uint256 i = 0; i < accessListAdmin.length; i++) {
        if (tx.origin == accessListAdmin[i]) {
          access = true;
          break;
        }
      }
      if (!access) {
        revert IAccessSystemErrors.AccessSystem_NoPermission(tx.origin, ADMIN);
      }
    }
    _;
  }

  modifier onlyObjectOwner(uint256 smartObjectId) {
    // check enforcement
    if (_isEnforced()) {
      if (IWorldWithEntryContext(_world()).initialMsgSender() != _getOwner(smartObjectId)) {
        revert IAccessSystemErrors.AccessSystem_NoPermission(
          IWorldWithEntryContext(_world()).initialMsgSender(),
          bytes32("OWNER")
        );
      }
    }
    _;
  }

  modifier onlySystemApproved() {
    ResourceId systemId = SystemRegistry.get(address(this));
    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListApproved = AccessRolePerSys.get(systemId, APPROVED);
      bool access;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          access = true;
          break;
        }
      }
      if (!access) {
        revert IAccessSystemErrors.AccessSystem_NoPermission(_msgSender(), APPROVED);
      }
    }
    _;
  }

  modifier onlyAdminOrObjectOwner(uint256 smartObjectId) {
    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListAdmin = AccessRole.get(ADMIN);
      bool adminAccess;
      for (uint256 i = 0; i < accessListAdmin.length; i++) {
        if (tx.origin == accessListAdmin[i]) {
          adminAccess = true;
          break;
        }
      }
      if (!(adminAccess || IWorldWithEntryContext(_world()).initialMsgSender() == _getOwner(smartObjectId))) {
        revert IAccessSystemErrors.AccessSystem_NoPermission(
          IWorldWithEntryContext(_world()).initialMsgSender(),
          bytes32("OWNER")
        );
      }
    }
    _;
  }

  modifier onlyAdminOrEphInvOwner(uint256 smartObjectId, address ephInvOwner) {
    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListAdmin = AccessRole.get(ADMIN);
      bool adminAccess;
      for (uint256 i = 0; i < accessListAdmin.length; i++) {
        if (tx.origin == accessListAdmin[i]) {
          adminAccess = true;
          break;
        }
      }
      if (!adminAccess || IWorldWithEntryContext(_world()).initialMsgSender() != ephInvOwner) {
        if (!adminAccess) {
          revert IAccessSystemErrors.AccessSystem_NoPermission(tx.origin, ADMIN);
        } else {
          revert IAccessSystemErrors.AccessSystem_NoPermission(
            IWorldWithEntryContext(_world()).initialMsgSender(),
            bytes32("OWNER")
          );
        }
      }
    }
    _;
  }

  modifier noAccess() {
    // check enforcement
    if (_isEnforced()) {
      revert IAccessSystemErrors.AccessSystem_NoPermission(address(0), bytes32(0));
    }
    _;
  }

  modifier onlyAdminOrSystemApproved(uint256 smartObjectId) {
    ResourceId systemId = SystemRegistry.get(address(this));

    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListAdmin = AccessRole.get(ADMIN);
      bool adminAccess;

      for (uint256 i = 0; i < accessListAdmin.length; i++) {
        if (tx.origin == accessListAdmin[i]) {
          adminAccess = true;
          break;
        }
      }
      address[] memory accessListApproved = AccessRolePerSys.get(systemId, APPROVED);

      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }

      if (!(adminAccess || approvedAccess)) {
        if (!adminAccess && ResourceId.unwrap(SystemRegistry.get(_msgSender())) == bytes32(0)) {
          revert IAccessSystemErrors.AccessSystem_NoPermission(tx.origin, ADMIN);
        } else {
          revert IAccessSystemErrors.AccessSystem_NoPermission(_msgSender(), APPROVED);
        }
      }
    }
    _;
  }

  function _getOwner(uint256 smartObjectId) internal returns (address owner) {
    owner = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartObjectId);
  }

  function _isEnforced() internal view returns (bool) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, msg.sig));
    return AccessEnforcement.get(target);
  }
}
