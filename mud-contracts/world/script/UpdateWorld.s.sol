// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

// World imports
import { World } from "@latticexyz/world/src/World.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import { AccessRole, AccessEnforcement } from "../src/codegen/index.sol";
import { AccessControl } from "../src/modules/access-control/systems/AccessControl.sol";
import { Utils as AccessUtils } from "../src/modules/access-control/Utils.sol";
import { EntityRecord } from "../src/modules/entity-record/systems/EntityRecord.sol";
import { ERC721System } from "../src/modules/eve-erc721-puppet/ERC721System.sol";
import { EphemeralInventory } from "../src/modules/inventory/systems/EphemeralInventory.sol";
import { Inventory } from "../src/modules/inventory/systems/Inventory.sol";
import { LocationSystem } from "../src/modules/location/systems/LocationSystem.sol";
import { SmartCharacter } from "../src/modules/smart-character/systems/SmartCharacter.sol";
import { SmartDeployable } from "../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { SmartStorageUnit } from "../src/modules/smart-storage-unit/systems/SmartStorageUnit.sol";
import { StaticData } from "../src/modules/static-data/systems/StaticData.sol";

contract UpdateWorld is Script {
  using AccessUtils for bytes14;

  bytes14 constant EVE_WORLD_NAMESPACE = bytes14("eveworld");

  AccessControl accessControl;
  EntityRecord entityRecord;
  ERC721System erc721System;
  EphemeralInventory ephemeralInventory;
  Inventory inventory;
  LocationSystem location;
  SmartCharacter character;
  SmartDeployable deployable;
  SmartStorageUnit smartStorage;
  StaticData staticData;

  // SYSTEM NAMES
  bytes16 constant ACCESS_CONTROL_SYSTEM_NAME = "AccessControl";
  bytes16 constant ENTITY_RECORD_SYSTEM_NAME = "EntityRecord";
  bytes16 constant ERC721_SYSTEM_NAME = "ERC721System";
  bytes16 constant EPHEMERAL_INVENTORY_SYSTEM_NAME = "EphemeralInv";
  bytes16 constant INVENTORY_SYSTEM_NAME = "Inventory";
  bytes16 constant LOCATION_SYSTEM_NAME = "Location";
  bytes16 constant SMART_CHARACTER_SYSTEM_NAME = "SmartCharacter";
  bytes16 constant SMART_DEPLOYABLE_SYSTEM_NAME = "SmartDeployable";
  bytes16 constant SMART_STORAGE_UNIT_SYSTEM_NAME = "SmartStorageUnit";
  bytes16 constant STATIC_DATA_SYSTEM_NAME = "StaticData";
  
  // SYSTEM IDs
  ResourceId ACCESS_CONTROL_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: ACCESS_CONTROL_SYSTEM_NAME });
  ResourceId ENTITY_RECORD_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: ENTITY_RECORD_SYSTEM_NAME });
  ResourceId ERC721_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: ERC721_SYSTEM_NAME });
  ResourceId EPHEMERAL_INVENTORY_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: EPHEMERAL_INVENTORY_SYSTEM_NAME });
  ResourceId INVENTORY_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: INVENTORY_SYSTEM_NAME });
  ResourceId LOCATION_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: LOCATION_SYSTEM_NAME });
  ResourceId SMART_CHARACTER_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: SMART_CHARACTER_SYSTEM_NAME });
  ResourceId SMART_DEPLOYABLE_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: SMART_DEPLOYABLE_SYSTEM_NAME });
  ResourceId SMART_STORAGE_UNIT_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: SMART_STORAGE_UNIT_SYSTEM_NAME });
  ResourceId STATIC_DATA_SYSTEM_ID = WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: EVE_WORLD_NAMESPACE, name: STATIC_DATA_SYSTEM_NAME });


  function run(address worldAddress) external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    vm.startBroadcast(deployerPrivateKey);
    // deploy new contracts
    accessControl = new AccessControl();
    entityRecord = new EntityRecord();
    erc721System = new ERC721System();
    ephemeralInventory = new EphemeralInventory();
    inventory = new Inventory();
    location = new LocationSystem();
    character = new SmartCharacter();
    deployable = new SmartDeployable();
    smartStorage = new SmartStorageUnit();
    staticData = new StaticData();

    // devnet deploy needs tables included
    // // register AccessRole adn AccessEnforcement Tables (they are used by AccessControl)
    // AccessRole.register(EVE_WORLD_NAMESPACE.accessRoleTableId());
    // AccessEnforcement.register(EVE_WORLD_NAMESPACE.accessEnforcementTableId());

    // register AccessControl and functions
    world.registerSystem(ACCESS_CONTROL_SYSTEM_ID, System(accessControl), true);
    world.registerFunctionSelector(ACCESS_CONTROL_SYSTEM_ID, "setAccessListByRole(bytes32,address[])");
    world.registerFunctionSelector(ACCESS_CONTROL_SYSTEM_ID, "setAccessEnforcement(bytes32,bool)");

    // register updated Systems (no function changes, only modifiers added)
    world.registerSystem(ENTITY_RECORD_SYSTEM_ID, System(entityRecord), true);
    world.registerSystem(ERC721_SYSTEM_ID, System(erc721System), true);
    world.registerSystem(EPHEMERAL_INVENTORY_SYSTEM_ID, System(ephemeralInventory), true);
    world.registerSystem(INVENTORY_SYSTEM_ID, System(inventory), true);
    world.registerSystem(LOCATION_SYSTEM_ID, System(location), true);
    world.registerSystem(SMART_CHARACTER_SYSTEM_ID, System(character), true);
    world.registerSystem(SMART_DEPLOYABLE_SYSTEM_ID, System(deployable), true);
    world.registerSystem(SMART_STORAGE_UNIT_SYSTEM_ID, System(smartStorage), true);
    world.registerSystem(STATIC_DATA_SYSTEM_ID, System(staticData), true);

    vm.stopBroadcast();
  }
}