/// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { IWorld } from "../../../src/codegen/world/IWorld.sol";
import { HasRole } from "../../../src/codegen/tables/HasRole.sol";
import { AccessConfig, AccessConfigData } from "../../../src/codegen/tables/AccessConfig.sol";
import { IAccessRulesConfigErrors } from "../../../src/modules/access-control/IAccessRulesConfigErrors.sol";
import { IAccessRuleMockErrors } from "./IAccessRuleMockErrors.sol";
import { EnforcementLevel } from "./IAccessRuleMock.sol";
import { ACCESS_CONTROL_DEPLOYMENT_NAMESPACE as ACCESS_CONTROL_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";
import { HAS_ROLE_TABLE_ID, ACCESS_CONFIG_TABLE_ID } from "./mockconstants.sol";

/**
 * @title Access Rule Mock contract (example)
 * @author The CCP Games Development Team
 * @notice A contract which implements access control enforcement logic configurated in {AccessControl} and {AccessRulesConfig}.
 * @dev The function in this is intended to be a hook logic implementation and associated (and thereafter
 *   executed) with another target function that implements the `hookable()` modfier. 
 * Association occurs by using the {HookCore} functionality of the Smart Object Framework. After asosciation with a
 *   target function, this hook logic will then also be executed anytime the target function is executed for a given
 *   `entityId`.
 */
contract AccessRuleMock is System {


  /**
   * @dev All of the following accessRule implements ahook based logic that follows access control
   *   rules enforcement for a specific configuration.
   * e.g., `accessRule()` will use the EnforcementLevel and RolesByContext configuration set for `configId = 1` in
   * {AccessConfig}.
   *
   * In all instances, if the accessing account value is not a member of one of the defined roleIds for its context
   *   AND that access context is configured to be enforced, then an {AccessRulesUnauthorizedAccount} error
   *   will be thrown.
   *   
   * @param entityId - currently the parameters of hooks must match the params of thier target function. See {EveSystem-_executeHook}.
   */
  function accessRule(uint256 entityId) public {
    // preconfigured enforcment and roles at configId 1
    uint256 configId = 1;
    _accessControlByConfigOR(entityId, configId);
  }

  /**
   * @dev Role based access control enforcement logic per `entityId` and `configId`
   * NOTE: this is an OR implementation. That is to say, if the account being checked is a member of any of the roles
   *   set in the configuration for its context, then access is granted.
   *
   * Throws an {AccessRulesUnauthorizedAccount} error if the account of any of the enforced access contexts is
   *   not a member of any of the configured roles for that context.
   */
  function _accessControlByConfigOR(uint256 entityId, uint256 configId) internal {
    AccessConfigData memory accessConfigData = AccessConfig.get(ACCESS_CONFIG_TABLE_ID, entityId, configId);
   
    EnforcementLevel configuredEnforcement = EnforcementLevel(accessConfigData.enforcementLevel);
    IAccessRuleMockErrors.AccessReport memory transientReport;
    IAccessRuleMockErrors.AccessReport memory originReport;
    bool access = false;
    
    if(uint8(configuredEnforcement) > 0) {
      if(configuredEnforcement == EnforcementLevel.TRANSIENT) {
        for (uint256 i = 0; i < accessConfigData.initialMsgSender.length; i++) {
          if (HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.initialMsgSender[i], world().initialMsgSender())) {
            access = true;
            break;
          }
        }
        if (!access) {
          transientReport = IAccessRuleMockErrors.AccessReport(
            world().initialMsgSender(),
            accessConfigData.initialMsgSender
          );

          revert IAccessRuleMockErrors.AccessRulesUnauthorizedAccount(
            configuredEnforcement,
            transientReport,
            originReport
          );
        }
      } else if (configuredEnforcement == EnforcementLevel.ORIGIN) {
        for (uint256 i = 0; i < accessConfigData.txOrigin.length; i++) {
          if (HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.txOrigin[i], tx.origin)) {
            access = true;
            break;
          }
        }
        if (!access) {
          originReport = IAccessRuleMockErrors.AccessReport(
            tx.origin,
            accessConfigData.txOrigin
          );

          revert IAccessRuleMockErrors.AccessRulesUnauthorizedAccount(
            configuredEnforcement,
            transientReport,
            originReport
          );
        }
      } else {
        uint256 len1 = accessConfigData.initialMsgSender.length;
        uint256 len2 = accessConfigData.txOrigin.length;
        uint256 count;
        uint256 length;
        bytes32[] memory longest;
        EnforcementLevel context;
        if (len1 > len2) {
          length = len2;
          count = len1 - len2;
          context = EnforcementLevel.TRANSIENT;
        } else {
          length = len1;
          count = len2 - len1;
          context = EnforcementLevel.ORIGIN;
        }

        for (uint256 i = 0; i < length; i++) {
          if (
            HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.initialMsgSender[i], world().initialMsgSender()) ||
            HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.txOrigin[i], tx.origin)
          ) {
            access = true;
            break;
          }
        }
        if (count > 0) {
          for (uint256 i = 0; i < count; i++) {
            if (context == EnforcementLevel.TRANSIENT){
              if (
                HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.initialMsgSender[i+count], world().initialMsgSender())
              ) {
                access = true;
                break;
              }
            } else {
              if (
                HasRole.getHasRole(HAS_ROLE_TABLE_ID, accessConfigData.txOrigin[i+count], tx.origin)
              ) {
                access = true;
                break;
              }
            }
          }
        }
        if (!access) {
          transientReport = IAccessRuleMockErrors.AccessReport(
            world().initialMsgSender(),
            accessConfigData.initialMsgSender
          );
          originReport = IAccessRuleMockErrors.AccessReport(
            tx.origin,
            accessConfigData.txOrigin
          );

          revert IAccessRuleMockErrors.AccessRulesUnauthorizedAccount(
            configuredEnforcement,
            transientReport,
            originReport
          );
        }
      }
    } else { // EnforcementLevel NULL
      return;
    }
  }

  function world() internal view returns (IWorld) {
    return IWorld(_world());
  }
}
