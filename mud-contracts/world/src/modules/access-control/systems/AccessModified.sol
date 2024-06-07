// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;
import { console } from "forge-std/console.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM, RESOURCE_TABLE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceAccess } from "@latticexyz/world/src/codegen/tables/ResourceAccess.sol";

import { IERC721 } from "../../eve-erc721-puppet/IERC721.sol";
import { Utils as SmartDeployableUtils } from "../../smart-deployable/Utils.sol";
import { DeployableTokenTable } from "../../../codegen/tables/DeployableTokenTable.sol";

import { AccessRole, AccessEnforcement } from "../../../codegen/index.sol";

import { IAccessControlErrors } from "../interfaces/IAccessControlErrors.sol";
import { ADMIN, APPROVED, EVE_WORLD_NAMESPACE } from "../constants.sol";

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
        revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, ADMIN);
      }
    }
    _;
  }

  modifier onlyObjectOwner(uint256 smartObjectId) {
    // check enforcement
    if (_isEnforced()) {
      if (IWorldKernel(_world()).initialMsgSender() != _getOwner(smartObjectId)) {
        revert IAccessControlErrors.AccessControl_NoPermission(IWorldKernel(_world()).initialMsgSender(), bytes32("OWNER"));
      }
    }
    _;
  }

  modifier onlyApproved() {
    // check enforcement
    if (_isEnforced()) {
      address[] memory accessListApproved = AccessRole.get(APPROVED);
      bool access;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          access = true;
          break;
        }
      }
      if (!access) {
        revert IAccessControlErrors.AccessControl_NoPermission(_msgSender(), APPROVED);
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
      if (!adminAccess || IWorldKernel(_world()).initialMsgSender() != _getOwner(smartObjectId)) {
        if(!adminAccess) {
          revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, ADMIN);
        } else {
          revert IAccessControlErrors.AccessControl_NoPermission(IWorldKernel(_world()).initialMsgSender(), bytes32("OWNER"));
        }
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
      if (!adminAccess || IWorldKernel(_world()).initialMsgSender() != ephInvOwner) {
        if(!adminAccess) {
          revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, ADMIN);
        } else {
          revert IAccessControlErrors.AccessControl_NoPermission(IWorldKernel(_world()).initialMsgSender(), bytes32("OWNER"));
        }
      }
    }
    _;
  }

  modifier noAccess() {
    // check enforcement
    if (_isEnforced()) {
      revert IAccessControlErrors.AccessControl_NoPermission(address(0), bytes32(0));
    }
    _;
  }

  modifier onlyAdminWithEphInvOwnerOrApproved(uint256 smartObjectId, address ephInvOwner) {
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
      address[] memory accessListApproved = AccessRole.get(APPROVED);
      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }
      if (!approvedAccess) {
        revert IAccessControlErrors.AccessControl_NoPermission(_msgSender(), APPROVED);
      } else {
        if (!(adminAccess && IWorldKernel(_world()).initialMsgSender() == ephInvOwner)) {
          if(!adminAccess) {
            revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, ADMIN);
          } else if (IWorldKernel(_world()).initialMsgSender() != ephInvOwner) {
            revert IAccessControlErrors.AccessControl_NoPermission(IWorldKernel(_world()).initialMsgSender(), bytes32("OWNER"));
          }
        }
      }
    }
    _;
  }

  modifier onlyAdminWithObjectOwnerOrApproved(uint256 smartObjectId) {
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
      address[] memory accessListApproved = AccessRole.get(APPROVED);
    
      bool approvedAccess;
      for (uint256 i = 0; i < accessListApproved.length; i++) {
        if (_msgSender() == accessListApproved[i]) {
          approvedAccess = true;
          break;
        }
      }
      if (!approvedAccess) {
        revert IAccessControlErrors.AccessControl_NoPermission(_msgSender(), APPROVED);
      } else {
        if (!(adminAccess && IWorldKernel(_world()).initialMsgSender() == _getOwner(smartObjectId))) {
          if(!adminAccess) {
            revert IAccessControlErrors.AccessControl_NoPermission(tx.origin, ADMIN);
          } else if (IWorldKernel(_world()).initialMsgSender() != _getOwner(smartObjectId)) {
            revert IAccessControlErrors.AccessControl_NoPermission(IWorldKernel(_world()).initialMsgSender(), bytes32("OWNER"));
          }
        }
      }
    }
    _;
  }

  function _getOwner(uint256 smartObjectId) internal returns (address owner) {
    owner = IERC721(DeployableTokenTable.getErc721Address(EVE_WORLD_NAMESPACE.deployableTokenTableId())).ownerOf(
      smartObjectId
    );
  }

  function _isEnforced() internal view returns (bool) {
    ResourceId systemId = SystemRegistry.get(address(this));
    bytes32 target = keccak256(abi.encodePacked(systemId, msg.sig));
    return AccessEnforcement.get(target);
  }
}
