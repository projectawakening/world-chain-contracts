// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { MudTest } from "@latticexyz/world/test/MudTest.t.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIdInstance } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

// Smart Object Framework imports
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Entity } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/Entity.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";

// Local namespace tables
import { Inventory, Tenant, EntityRecord, EntityRecordData, EntityRecordMetadata, EntityRecordMetadataData, CharactersByAccount, Characters, CharactersData, EphemeralInventory, SmartAssembly, Fuel, Location } from "../../src/namespaces/evefrontier/codegen/index.sol";

// Local namespace systems
import { AccessSystem } from "../../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { DeployableSystem, deployableSystem } from "../../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { SmartAssemblySystem, smartAssemblySystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventorySystem, inventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { LocationSystem, locationSystem } from "../../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { FuelSystem, fuelSystem } from "../../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { SmartCharacterSystem, smartCharacterSystem } from "../../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";

// Types and parameters
import { EntityRecordParams, EntityMetadataParams } from "../../src/namespaces/evefrontier/systems/entity-record/types.sol";

contract SmartCharacterTest is MudTest {
  using WorldResourceIdInstance for ResourceId;

  IWorldWithContext public world;

  // Test variables
  uint256 smartCharacterClassId;
  uint256 smartCharacterObjectId;
  uint256 smartCharacterTypeId;
  bytes32 tenantId;

  // Smart Object Entity Record variables
  uint256 constant SMART_CHARACTER_ITEM_ID = 1337;

  // metadata variables
  string constant NAME = "Hiro Protagonist";
  string constant DAPP_URL = "https://dapp.hiro.com";
  string constant DESCRIPTION = "Spacefaring adventurer and katana-wielder.";

  // character variables
  uint256 tribeId = 101;

  uint256 singletonClassId;
  uint256 singletonObjectId;
  uint256 ephemeralSingletonClassId;
  uint256 ephemeralSingletonObjectId;
  uint256 nonSingletonObjectId;

  EntityRecordParams entityRecordParams;
  EntityMetadataParams entityMetadataParams;

  // Test addresses
  address deployer;
  address alice;
  address bob;

  function setUp() public virtual override {
    vm.pauseGasMetering();
    super.setUp();
    // Deploy a new World
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    world = IWorldWithContext(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);
    smartCharacterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    // Initialize addresses
    string memory mnemonic = "test test test test test test test test test test test junk";
    deployer = vm.addr(vm.deriveKey(mnemonic, 0));
    alice = vm.addr(vm.deriveKey(mnemonic, 2));
    bob = vm.addr(vm.deriveKey(mnemonic, 3));

    vm.startPrank(deployer, deployer);

    // Setup tenant
    tenantId = Tenant.get();

    smartCharacterClassId = _calculateObjectId(smartCharacterTypeId, 0, false);
    smartCharacterObjectId = _calculateObjectId(smartCharacterTypeId, SMART_CHARACTER_ITEM_ID, true);
    entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartCharacterTypeId,
      itemId: SMART_CHARACTER_ITEM_ID,
      volume: 0
    });
    entityMetadataParams = EntityMetadataParams({ name: NAME, dappURL: DAPP_URL, description: DESCRIPTION });

    vm.stopPrank();
  }

  function test_createCharacter() public {
    vm.startPrank(alice, deployer);

    // entity record sanity check reverts are already covered in the EntityRecordTest SmartCharacter interaction test
    assertEq(EntityRecord.getExists(smartCharacterObjectId), false);
    assertEq(Characters.getExists(smartCharacterObjectId), false);
    assertEq(CharactersByAccount.getSmartObjectId(alice), 0);
    address owner = ownershipSystem.owner(smartCharacterObjectId);
    assertEq(owner, address(0));

    smartCharacterSystem.createCharacter(
      smartCharacterObjectId,
      alice,
      tribeId,
      entityRecordParams,
      entityMetadataParams
    );

    EntityRecordData memory entityRecord = EntityRecord.get(smartCharacterObjectId);

    assertEq(entityRecord.exists, true);
    assertEq(entityRecord.tenantId, tenantId);
    assertEq(entityRecord.typeId, smartCharacterTypeId);
    assertEq(entityRecord.itemId, SMART_CHARACTER_ITEM_ID);
    assertEq(entityRecord.volume, 0);

    EntityRecordMetadataData memory entityRecordMetaData = EntityRecordMetadata.get(smartCharacterObjectId);

    assertEq(entityRecordMetaData.name, NAME);
    assertEq(entityRecordMetaData.dappURL, DAPP_URL);
    assertEq(entityRecordMetaData.description, DESCRIPTION);

    CharactersData memory character = Characters.get(smartCharacterObjectId);

    assertEq(character.exists, true);
    assertEq(character.tribeId, tribeId);
    assertEq(character.createdAt, block.timestamp);

    assertEq(CharactersByAccount.getSmartObjectId(alice), smartCharacterObjectId);

    owner = ownershipSystem.owner(smartCharacterObjectId);
    assertEq(owner, alice);

    vm.stopPrank();
  }

  function test_updateTribe() public {
    vm.startPrank(alice, deployer);
    smartCharacterSystem.createCharacter(
      smartCharacterObjectId,
      alice,
      tribeId,
      entityRecordParams,
      entityMetadataParams
    );

    assertEq(Characters.getTribeId(smartCharacterObjectId), tribeId);
    uint256 newTribeId = 102;
    smartCharacterSystem.updateTribeId(smartCharacterObjectId, newTribeId);

    assertEq(Characters.getTribeId(smartCharacterObjectId), newTribeId);

    vm.stopPrank();
  }

  function test_removeCharacter() public {
    vm.startPrank(alice, deployer);
    smartCharacterSystem.createCharacter(
      smartCharacterObjectId,
      alice,
      tribeId,
      entityRecordParams,
      entityMetadataParams
    );
    vm.stopPrank();

    address owner = ownershipSystem.owner(smartCharacterObjectId);
    assertEq(owner, alice);

    vm.startPrank(deployer);
    smartCharacterSystem.removeCharacter(smartCharacterObjectId);

    assertEq(Characters.getExists(smartCharacterObjectId), false);
    owner = ownershipSystem.owner(smartCharacterObjectId);
    assertEq(owner, address(0));

    vm.stopPrank();
  }

  // Helper function to setup item records
  function _setupEntityRecord(uint256 entityId, uint256 typeId, uint256 itemId, uint256 volume) internal {
    uint256 classId = uint256(keccak256(abi.encodePacked(tenantId, typeId)));

    if (itemId != 0) {
      // For singleton items
      EntityRecord.set(entityId, true, tenantId, typeId, itemId, volume);

      if (!EntityRecord.getExists(classId)) {
        EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
      }
    } else {
      // For non-singleton items
      EntityRecord.set(classId, true, tenantId, typeId, 0, volume);
    }

    if (!Entity.getExists(classId)) {
      entitySystem.registerClass(classId, new ResourceId[](0));
    }
  }

  // Helper function to calculate itemObjectId
  function _calculateObjectId(uint256 typeId, uint256 itemId, bool isSingleton) internal view returns (uint256) {
    if (isSingleton) {
      // For singleton items: hash of tenantId and itemId
      return uint256(keccak256(abi.encodePacked(tenantId, itemId)));
    } else {
      // For non-singleton items: hash of typeId
      return uint256(keccak256(abi.encodePacked(tenantId, typeId)));
    }
  }
}
