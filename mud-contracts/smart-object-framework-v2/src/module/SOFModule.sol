// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { Module } from "@latticexyz/world/src/Module.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { StoreRegistrationSystem, FieldLayout, Schema } from "@latticexyz/world/src/modules/init/implementations/StoreRegistrationSystem.sol";
import { WorldRegistrationSystem } from "@latticexyz/world/src/modules/init/implementations/WorldRegistrationSystem.sol";
import { REGISTRATION_SYSTEM_ID } from "@latticexyz/world/src/modules/init/constants.sol";

import { CallAccess } from "../namespaces/evefrontier/codegen/tables/CallAccess.sol";
import { AccessConfig } from "../namespaces/evefrontier/codegen/tables/AccessConfig.sol";
import { Role } from "../namespaces/evefrontier/codegen/tables/Role.sol";
import { HasRole } from "../namespaces/evefrontier/codegen/tables/HasRole.sol";
import { Entity } from "../namespaces/evefrontier/codegen/tables/Entity.sol";
import { EntityTagMap } from "../namespaces/evefrontier/codegen/tables/EntityTagMap.sol";
import { Initialized } from "../namespaces/evefrontier/codegen/tables/Initialized.sol";

import { AccessConfigSystem, accessConfigSystem } from "../namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { CallAccessSystem, callAccessSystem } from "../namespaces/evefrontier/codegen/systems/CallAccessSystemLib.sol";
import { EntitySystem, entitySystem } from "../namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { RoleManagementSystem, roleManagementSystem } from "../namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { TagSystem, tagSystem } from "../namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { SOFAccessSystem, sOFAccessSystem } from "../namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { runSetSOFCallAccess } from "../../scripts/SetSOFCallAccess.s.sol";
import { runEntitySystemAccessConfig } from "../../scripts/EntitySystemAccessConfig.s.sol";
import { runRoleManagementSystemAccessConfig } from "../../scripts/RoleManagementSystemAccessConfig.s.sol";
import { runTagSystemAccessConfig } from "../../scripts/TagSystemAccessConfig.s.sol";

contract SOFModule is Module {
  using WorldResourceIdInstance for ResourceId;

  AccessConfigSystem internal immutable accessConfigSystemAddress;
  CallAccessSystem internal immutable callAccessSystemAddress;
  EntitySystem internal immutable entitySystemAddress;
  RoleManagementSystem internal immutable roleManagementSystemAddress;
  TagSystem internal immutable tagSystemAddress;
  SOFAccessSystem internal immutable sOFAccessSystemAddress;

  constructor(
    AccessConfigSystem _accessConfigSystem,
    CallAccessSystem _callAccessSystem,
    EntitySystem _entitySystem,
    RoleManagementSystem _roleManagementSystem,
    TagSystem _tagSystem,
    SOFAccessSystem _sOFAccessSystem
  ) {
    accessConfigSystemAddress = _accessConfigSystem;
    callAccessSystemAddress = _callAccessSystem;
    entitySystemAddress = _entitySystem;
    roleManagementSystemAddress = _roleManagementSystem;
    tagSystemAddress = _tagSystem;
    sOFAccessSystemAddress = _sOFAccessSystem;
  }

  function installRoot(bytes memory) public virtual override {
    revert("root install not supported");
  }

  function install(bytes memory) public virtual override {
    // TODO in a newer MUD version you can use world/storeRegistrationSystem and avoid _world entirely
    IBaseWorld world = IBaseWorld(WorldContextConsumerLib._world());

    // Namespaces
    ResourceId namespace1 = CallAccess._tableId.getNamespaceId();
    if (!ResourceIds.getExists(namespace1)) {
      // worldRegistrationSystem.callFrom(_msgSender()).registerNamespace(namespace1);

      world.callFrom(_msgSender(), REGISTRATION_SYSTEM_ID, abi.encodeCall(
        WorldRegistrationSystem.registerNamespace,
        (namespace1)
      ));
    }
    ResourceId namespace2 = sOFAccessSystem.toResourceId().getNamespaceId();
    if (!ResourceIds.getExists(namespace2)) {
      // worldRegistrationSystem.callFrom(_msgSender()).registerNamespace(namespace2);

      world.callFrom(_msgSender(), REGISTRATION_SYSTEM_ID, abi.encodeCall(
        WorldRegistrationSystem.registerNamespace,
        (namespace2)
      ));
    }

    // Tables
    /*if (!ResourceIds.getExists(CallAccess._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        CallAccess._tableId,
        CallAccess._fieldLayout,
        CallAccess._keySchema,
        CallAccess._valueSchema,
        CallAccess.getKeyNames(),
        CallAccess.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(AccessConfig._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        AccessConfig._tableId,
        AccessConfig._fieldLayout,
        AccessConfig._keySchema,
        AccessConfig._valueSchema,
        AccessConfig.getKeyNames(),
        AccessConfig.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Role._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        Role._tableId,
        Role._fieldLayout,
        Role._keySchema,
        Role._valueSchema,
        Role.getKeyNames(),
        Role.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(HasRole._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        HasRole._tableId,
        HasRole._fieldLayout,
        HasRole._keySchema,
        HasRole._valueSchema,
        HasRole.getKeyNames(),
        HasRole.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Entity._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        Entity._tableId,
        Entity._fieldLayout,
        Entity._keySchema,
        Entity._valueSchema,
        Entity.getKeyNames(),
        Entity.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(EntityTagMap._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        EntityTagMap._tableId,
        EntityTagMap._fieldLayout,
        EntityTagMap._keySchema,
        EntityTagMap._valueSchema,
        EntityTagMap.getKeyNames(),
        EntityTagMap.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Initialized._tableId)) {
      storeRegistrationSystem.callFrom(_msgSender()).registerTable(
        Initialized._tableId,
        Initialized._fieldLayout,
        Initialized._keySchema,
        Initialized._valueSchema,
        Initialized.getKeyNames(),
        Initialized.getFieldNames()
      );
    }*/
    if (!ResourceIds.getExists(CallAccess._tableId)) {
      _registerTable(
        CallAccess._tableId,
        CallAccess._fieldLayout,
        CallAccess._keySchema,
        CallAccess._valueSchema,
        CallAccess.getKeyNames(),
        CallAccess.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(AccessConfig._tableId)) {
      _registerTable(
        AccessConfig._tableId,
        AccessConfig._fieldLayout,
        AccessConfig._keySchema,
        AccessConfig._valueSchema,
        AccessConfig.getKeyNames(),
        AccessConfig.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Role._tableId)) {
      _registerTable(
        Role._tableId,
        Role._fieldLayout,
        Role._keySchema,
        Role._valueSchema,
        Role.getKeyNames(),
        Role.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(HasRole._tableId)) {
      _registerTable(
        HasRole._tableId,
        HasRole._fieldLayout,
        HasRole._keySchema,
        HasRole._valueSchema,
        HasRole.getKeyNames(),
        HasRole.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Entity._tableId)) {
      _registerTable(
        Entity._tableId,
        Entity._fieldLayout,
        Entity._keySchema,
        Entity._valueSchema,
        Entity.getKeyNames(),
        Entity.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(EntityTagMap._tableId)) {
      _registerTable(
        EntityTagMap._tableId,
        EntityTagMap._fieldLayout,
        EntityTagMap._keySchema,
        EntityTagMap._valueSchema,
        EntityTagMap.getKeyNames(),
        EntityTagMap.getFieldNames()
      );
    }
    if (!ResourceIds.getExists(Initialized._tableId)) {
      _registerTable(
        Initialized._tableId,
        Initialized._fieldLayout,
        Initialized._keySchema,
        Initialized._valueSchema,
        Initialized.getKeyNames(),
        Initialized.getFieldNames()
      );
    }

    // Systems
    _registerSystem(accessConfigSystem.toResourceId(), accessConfigSystemAddress, true);
    _registerSystem(callAccessSystem.toResourceId(), callAccessSystemAddress, false);
    _registerSystem(entitySystem.toResourceId(), entitySystemAddress, true);
    _registerSystem(roleManagementSystem.toResourceId(), roleManagementSystemAddress, true);
    _registerSystem(tagSystem.toResourceId(), tagSystemAddress, true);
    _registerSystem(sOFAccessSystem.toResourceId(), sOFAccessSystemAddress, true);

    // Access config
    // TODO add CallAccess cleanup to relevant scripts - it could have stale addresses after system upgrades
    runSetSOFCallAccess(_msgSender());
    runEntitySystemAccessConfig(_msgSender());
    runRoleManagementSystemAccessConfig(_msgSender());
    runTagSystemAccessConfig(_msgSender());
  }

  /**
   * @dev Register a new system if it doesn't exist, or upgrade an existing one if its address has changed
   */
  function _registerSystem(ResourceId systemId, System system, bool openAccess) internal {
    // If the system doesn't exist, or must be upgraded, register it
    if (!ResourceIds.getExists(systemId) || Systems.getSystem(systemId) != address(system)) {
      //worldRegistrationSystem.callFrom(_msgSender()).registerSystem(systemId, system, openAccess);

      IBaseWorld world = IBaseWorld(WorldContextConsumerLib._world());
      world.callFrom(_msgSender(), REGISTRATION_SYSTEM_ID, abi.encodeCall(
        WorldRegistrationSystem.registerSystem,
        (systemId, system, openAccess)
      ));
    }
  }

  function _registerTable(
    ResourceId tableId,
    FieldLayout fieldLayout,
    Schema keySchema,
    Schema valueSchema,
    string[] memory keyNames,
    string[] memory fieldNames
  ) internal {
    IBaseWorld world = IBaseWorld(WorldContextConsumerLib._world());
    world.callFrom(_msgSender(), REGISTRATION_SYSTEM_ID, abi.encodeCall(
      StoreRegistrationSystem.registerTable,
      (tableId, fieldLayout, keySchema, valueSchema, keyNames, fieldNames)
    ));
  }
}