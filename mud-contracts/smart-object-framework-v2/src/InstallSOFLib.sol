// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { CallAccess } from "./namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { AccessConfig } from "./namespaces/evefrontier/codegen/tables/AccessConfig.sol";
import { Role } from "./namespaces/evefrontier/codegen/tables/Role.sol";
import { HasRole } from "./namespaces/evefrontier/codegen/tables/HasRole.sol";
import { Entity } from "./namespaces/evefrontier/codegen/tables/Entity.sol";
import { EntityTagMap } from "./namespaces/evefrontier/codegen/tables/EntityTagMap.sol";
import { Initialized } from "./namespaces/evefrontier/codegen/tables/Initialized.sol";

import { AccessConfigSystem, accessConfigSystem } from "./namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { EntitySystem, entitySystem } from "./namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { RoleManagementSystem, roleManagementSystem } from "./namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { TagSystem, tagSystem } from "./namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { SOFAccessSystem, sOFAccessSystem } from "./namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { runSetSOFCallAccess } from "../scripts/SetSOFCallAccess.s.sol";
import { runEntitySystemAccessConfig } from "../scripts/EntitySystemAccessConfig.s.sol";
import { runRoleManagementSystemAccessConfig } from "../scripts/RoleManagementSystemAccessConfig.s.sol";
import { runTagSystemAccessConfig } from "../scripts/TagSystemAccessConfig.s.sol";

library InstallSOFLib {
  using WorldResourceIdInstance for ResourceId;

  /**
   * @notice Deploys the SOF systems and atomically registers the SOF tables and systems, and configues their access.
   */
  function install() internal {
    _installUsingProvidedSystems(
      new AccessConfigSystem(),
      new EntitySystem(),
      new RoleManagementSystem(),
      new TagSystem(),
      new SOFAccessSystem()
    );
  }

  /**
   * @dev Public library function makes this an atomic delegatecall,
   * to preventing possible issues with installation being spread across multiple transactions.
   */
  function _installUsingProvidedSystems(
    AccessConfigSystem accessConfigSystemAddress,
    EntitySystem entitySystemAddress,
    RoleManagementSystem roleManagementSystemAddress,
    TagSystem tagSystemAddress,
    SOFAccessSystem sOFAccessSystemAddress
  ) public {
    // TODO in a newer MUD version you can use `worldRegistrationSystem` and avoid `_world` entirely
    IBaseWorld world = IBaseWorld(WorldContextConsumerLib._world());

    // Namespaces
    ResourceId namespace1 = CallAccess._tableId.getNamespaceId();
    if (!ResourceIds.getExists(namespace1)) {
      world.registerNamespace(namespace1);
    }
    ResourceId namespace2 = sOFAccessSystem.toResourceId().getNamespaceId();
    if (!ResourceIds.getExists(namespace2)) {
      world.registerNamespace(namespace2);
    }

    // Tables
    if (!ResourceIds.getExists(CallAccess._tableId)) {
      CallAccess.register();
    }
    if (!ResourceIds.getExists(AccessConfig._tableId)) {
      AccessConfig.register();
    }
    if (!ResourceIds.getExists(Role._tableId)) {
      Role.register();
    }
    if (!ResourceIds.getExists(HasRole._tableId)) {
      HasRole.register();
    }
    if (!ResourceIds.getExists(Entity._tableId)) {
      Entity.register();
    }
    if (!ResourceIds.getExists(EntityTagMap._tableId)) {
      EntityTagMap.register();
    }
    if (!ResourceIds.getExists(Initialized._tableId)) {
      Initialized.register();
    }

    // Systems
    _registerSystem(world, accessConfigSystem.toResourceId(), accessConfigSystemAddress);
    _registerSystem(world, entitySystem.toResourceId(), entitySystemAddress);
    _registerSystem(world, roleManagementSystem.toResourceId(), roleManagementSystemAddress);
    _registerSystem(world, tagSystem.toResourceId(), tagSystemAddress);
    _registerSystem(world, sOFAccessSystem.toResourceId(), sOFAccessSystemAddress);

    // Access config
    // TODO add CallAccess cleanup to relevant scripts - it could have stale addresses after system upgrades
    runSetSOFCallAccess();
    runEntitySystemAccessConfig();
    runRoleManagementSystemAccessConfig();
    runTagSystemAccessConfig();
  }

  /**
   * @dev Register a new public(!) system if it doesn't exist, or upgrade an existing one if its address has changed
   */
  function _registerSystem(IBaseWorld world, ResourceId systemId, System system) internal {
    // If the system doesn't exist, or must be upgraded, register it
    if (!ResourceIds.getExists(systemId) || Systems.getSystem(systemId) != address(system)) {
      world.registerSystem(systemId, system, true);
    }
  }
}