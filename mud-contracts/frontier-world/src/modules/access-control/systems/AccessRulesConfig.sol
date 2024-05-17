/// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { AccessConfig, AccessConfigData } from "../../../codegen/tables/AccessConfig.sol";
import { RolesByContext, EnforcementLevel } from "../types.sol";
import { IAccessRulesConfig } from "../interfaces/IAccessRulesConfig.sol";
import { IAccessRulesConfigErrors } from "../IAccessRulesConfigErrors.sol";
import { AccessControlLib } from "../AccessControlLib.sol";
import { Utils } from "../Utils.sol";
import { EveSystem } from "@eve/frontier-smart-object-framework/src/systems/internal/EveSystem.sol";

/**
 * @title Access Rules Config contract
 * @author The CCP Games Development Team
 * @notice Provides the abitlity to configure role access and enforcement level data for use in access control rules logic.
 * @dev A standalone MUD System which imlplements access control enforcement logic intended to be used as applied hook
 *   logic within the Smart Object Framework.
 */
contract AccessRulesConfig is EveSystem {
  using Utils for bytes14;

  /**
   * @dev Modifier that checks if `configId` is greater than zero. A zero value is dissallowed since it is ambiguous
   * as to whether or not the value has been set as zero or has never been set.
   */
  modifier checkConfigId(uint256 configId) {
    if(configId == 0) {
      revert IAccessRulesConfigErrors.AccessRulesConfigIdOutOfBounds();
      _;
    }
  }

  /**
   * @notice Sets a configuration of access control `roleIds` for each access context and assign these `roleIds` to an
   *   `entityId` and `configId` configuration. See {AccessControl} for more info on `roleIds`
   * @dev Stores {RolesByContext} data in the {AccessConfig} table, defined as bytes32 arrays.
   *   All {RolesByContext} array data is intented to store `roleIds` for various roles which have been created and
   *   managed in the {AccessControl} base contract. These `roleIds` are then used to verify access for account
   *   interactions. 
   *   There are three fields in {AccessConfig} which store `roleId` array data for the following three relevant access
   *   contexts:
   *   - a TRANSIENT CONTEXT variable tracked via `world().initialMsgSender()`. For world.call() and world.fallback(),
   *     this tracks the `msg.sender` of the initial call into the MUD World. Aternatively, for world.callfrom() it tracks the
   *     `delegator` (who is the payload signer of an ERC2771 MetaTxn). Useful to check access for the intended "actor" of
   *     transaction.
   *   - a MUD CONTEXT variable tracked via `_msgSender()`, which tracks the `msg.sender` in various MUD paths for both
   *     external and internally routed MUD System calls. Useful to check access for contracts and other direct
   *     `msg.sender` cases.
   *   - an ORIGIN CONTEXT tracked via `tx.origin`, which is the original transaction submitter. Useful to check access
   *     for EoAs and MetaTxn/UserOperation transaction submitters.
   *
   * Throws the error {AccessRulesConfigIdOutOfBounds} if `configId` is 0.
   *
   * @param entityId - the ID of the entity to set this access role data for.
   * @param configId - the configId to set this data. Allows for multiple different configurations per entityId
   * @param rolesByContext - the roleId array data for each context of this configuration
   */
  function setAccessControlRoles(
    uint256 entityId,
    uint256 configId,
    RolesByContext memory rolesByContext
  )
    external
    checkConfigId(configId)
    hookable(entityId, _systemId())
  {
    AccessConfig.setInitialMsgSender(
      _namespace().accessConfigTableId(), 
      entityId,
      configId,
      rolesByContext.initialMsgSender
    );
    AccessConfig.setMudMsgSender(
      _namespace().accessConfigTableId(), 
      entityId,
      configId,
      rolesByContext.mudMsgSender
    );
    AccessConfig.setTxOrigin(
      _namespace().accessConfigTableId(), 
      entityId,
      configId,
      rolesByContext.txOrigin
    );
  }

  /**
   * @notice Sets an enforcement level for a configuration, defining which access contexts shoud be enforced for executions
   *   related to `entityId` when that configuration is used.
   * @dev Stores EnforcementLevel data in the {AcessConfig} table defined as a unit8.
   *   EnforcementLevel data is an enum to define which access contexts we want to enforce: 
   *    - NULL, nothing is enforced at this level, this level is tantamount to turning the access enforcement off
   *    - TRANSIENT_ONLY, sets only the `world().initalMsgSender` context for enforcement
   *    - MUD_ONLY, sets only the MUD `_msgSender()` context for enforcement
   *    - ORIGIN_ONLY, sets only the `tx.origin`  context for enforcement
   *    - TRANSIENT_AND_MUD, sets `world().initalMsgSender` and `_msgSender()` context enforcement
   *    - TRANSIENT_AND_ORIGIN, sets `world().initalMsgSender` and `tx.origin` context enforcement
   *    - MUD_AND_ORIGIN, sets `_msgSender()` and `tx.origin` context enforcement
   *    - TRANSIENT_AND_MUD_AND_ORIGIN, sets all three contexts for enforcement
   *
   * Throws the error {AccessRulesConfigIdOutOfBounds} if `configId` is 0.
   *
   * @param entityId - the ID of the entity to set this access role data for.
   * @param configId - the configId to set this data. Allows for multiple different configurations per entityId
   * @param enforcementLevel - the EnforcementLevel value to store for this configuration
   */
  function setEnforcementLevel(
    uint256 entityId,
    uint256 configId,
    EnforcementLevel enforcementLevel
  )
    external
    checkConfigId(configId)
    hookable(entityId, _systemId())
  {
    AccessConfig.setEnforcementLevel(
      _namespace().accessConfigTableId(), 
      entityId,
      configId,
      uint8(enforcementLevel)
    );
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().accessRulesConfigSystemId();
  }
}