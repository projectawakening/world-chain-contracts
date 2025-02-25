// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Test } from "forge-std/Test.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { AccessConfig, HasRole, Entity, EntityTagMap, Role } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/index.sol";

import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { RoleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/role-management-system/RoleManagementSystem.sol";
import { IRoleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";

import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { AccessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/access-config-system/AccessConfigSystem.sol";

import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { EntitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/entity-system/EntitySystem.sol";

import { tagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { TagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/systems/tag-system/TagSystem.sol";

import { DeployableSystem } from "../src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { deployableSystem } from "../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { AccessSystem } from "../src/namespaces/evefrontier/systems/access-systems/AccessSystem.sol";
import { accessSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessSystemLib.sol";
import { FuelSystem } from "../src/namespaces/evefrontier/systems/fuel/FuelSystem.sol";
import { fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

import { inventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { InventorySystem } from "../src/namespaces/evefrontier/systems/inventory/InventorySystem.sol";
import { ephemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { EphemeralInventorySystem } from "../src/namespaces/evefrontier/systems/inventory/EphemeralInventorySystem.sol";
import { InventoryInteractSystem } from "../src/namespaces/evefrontier/systems/inventory/InventoryInteractSystem.sol";
import { inventoryInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { EntityRecordSystem } from "../src/namespaces/evefrontier/systems/entity-record/EntityRecordSystem.sol";
import { entityRecordSystem } from "../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { StaticDataSystem } from "../src/namespaces/evefrontier/systems/static-data/StaticDataSystem.sol";
import { staticDataSystem } from "../src/namespaces/evefrontier/codegen/systems/StaticDataSystemLib.sol";
import { LocationSystem } from "../src/namespaces/evefrontier/systems/location/LocationSystem.sol";
import { locationSystem } from "../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { SmartCharacterSystem } from "../src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { smartCharacterSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { SmartStorageUnitSystem } from "../src/namespaces/evefrontier/systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { smartStorageUnitSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { smartAssemblySystem } from "../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { locationSystem } from "../src/namespaces/evefrontier/codegen/systems/LocationSystemLib.sol";
import { SmartTurretSystem } from "../src/namespaces/evefrontier/systems/smart-turret/SmartTurretSystem.sol";
import { smartTurretSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { SmartGateSystem } from "../src/namespaces/evefrontier/systems/smart-gate/SmartGateSystem.sol";
import { smartGateSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";

import { Initialize } from "../src/namespaces/evefrontier/codegen/index.sol";

abstract contract EveTest is Test {
  address public worldAddress;
  IWorldWithContext world;

  string mnemonic = "test test test test test test test test test test test junk";

  uint256 deployerPK = vm.deriveKey(mnemonic, 0);
  address deployer = vm.addr(deployerPK);

  uint256 alicePK = vm.deriveKey(mnemonic, 2);
  address alice = vm.addr(alicePK);

  uint256 bobPK = vm.deriveKey(mnemonic, 3);
  address bob = vm.addr(bobPK);

  bytes32 adminRole = "admin";

  function setUp() public virtual {
    vm.startPrank(deployer);
    worldSetup();
    registerClasses();
    deploySmartObjectFramework();
    setupScopeAndAccess();
    vm.stopPrank();
  }

  function worldSetup() internal {
    worldAddress = vm.envAddress("WORLD_ADDRESS");
    StoreSwitch.setStoreAddress(worldAddress);

    world = IWorldWithContext(worldAddress);
  }

  function setupScopeAndAccess() internal {
    configureAdminRole();

    registerSmartStorageUnitClass(adminRole);
    registerInventoryItemClass(adminRole);
    registerSmartCharacterClass(adminRole);
    registerSmartTurretClass(adminRole);
    registerSmartGateClass(adminRole);

    configureDeployableAccess();
    configureEntityRecordAccess();
    configureStaticDataAccess();
    configureEphemeralInventoryAccess();
    configureInventoryAccess();
    configureInventoryInteractAccess();
    configureLocationAccess();
    configureSmartCharacterAccess();
    configureFuelAccess();
    configureSmartTurretAccess();
    configureSmartGateAccess();
  }

  function registerClasses() internal {
    Initialize.set(smartCharacterSystem.toResourceId(), uint256(keccak256(abi.encodePacked(uint256(2222)))));
    Initialize.set(smartStorageUnitSystem.toResourceId(), uint256(keccak256(abi.encodePacked(uint256(3333)))));
    Initialize.set(smartTurretSystem.toResourceId(), uint256(keccak256(abi.encodePacked(uint256(4444)))));
    Initialize.set(smartGateSystem.toResourceId(), uint256(keccak256(abi.encodePacked(uint256(5555)))));
    Initialize.set(inventorySystem.toResourceId(), uint256(bytes32("INVENTORY_ITEM"))); //TODO : This pattern is only for test
  }

  function configureAdminRole() internal {
    roleManagementSystem.createRole(adminRole, adminRole);
    // TODO: Grant admin role to address list
    roleManagementSystem.grantRole(adminRole, deployer);
  }

  // Only needed in tests.
  // In real deployments this is done by deploying SmartObjectFrameworkV2 to the same world.
  function deploySmartObjectFramework() public {
    AccessConfig.register();
    HasRole.register();
    Entity.register();
    EntityTagMap.register();
    Role.register();

    deployRoleManagementSystem();
    deployAccessConfigSystem();
    deployEntitySystem();
    deployTagSystem();
  }

  function deployRoleManagementSystem() internal {
    world.registerSystem(roleManagementSystem.toResourceId(), new RoleManagementSystem(), true);

    // Register all function selectors from IRoleManagementSystem interface
    string[5] memory signatures = [
      "createRole(bytes32,bytes32)",
      "transferRoleAdmin(bytes32,bytes32)",
      "grantRole(bytes32,address)",
      "revokeRole(bytes32,address)",
      "renounceRole(bytes32,address)"
    ];

    for (uint256 i = 0; i < signatures.length; i++) {
      world.registerFunctionSelector(roleManagementSystem.toResourceId(), signatures[i]);
    }
  }

  function deployAccessConfigSystem() internal {
    world.registerSystem(accessConfigSystem.toResourceId(), new AccessConfigSystem(), true);
    string[2] memory accessConfigSignatures = [
      "configureAccess(bytes32,bytes4,bytes32,bytes4)",
      "setAccessEnforcement(bytes32,bytes4,bool)"
    ];

    for (uint256 i = 0; i < accessConfigSignatures.length; i++) {
      world.registerFunctionSelector(accessConfigSystem.toResourceId(), accessConfigSignatures[i]);
    }
  }

  function deployEntitySystem() internal {
    world.registerSystem(entitySystem.toResourceId(), new EntitySystem(), true);
    string[2] memory entitySignatures = ["instantiate(uint256,uint256)", "registerClass(uint256,bytes32,ResourceId[])"];
    for (uint256 i = 0; i < entitySignatures.length; i++) {
      world.registerFunctionSelector(entitySystem.toResourceId(), entitySignatures[i]);
    }
  }

  function deployTagSystem() internal {
    world.registerSystem(tagSystem.toResourceId(), new TagSystem(), true);
    string[1] memory tagSignatures = ["setTags(uint256,(bytes32,bytes)[])"];
    for (uint256 i = 0; i < tagSignatures.length; i++) {
      world.registerFunctionSelector(tagSystem.toResourceId(), tagSignatures[i]);
    }
  }

  function configureDeployableAccess() internal {
    bytes4[8] memory deployableSignatures = [
      DeployableSystem.createAndAnchorDeployable.selector,
      DeployableSystem.registerDeployable.selector,
      DeployableSystem.registerDeployableToken.selector,
      DeployableSystem.destroyDeployable.selector,
      DeployableSystem.anchor.selector,
      DeployableSystem.unanchor.selector,
      DeployableSystem.globalPause.selector,
      DeployableSystem.globalResume.selector
    ];

    for (uint256 i = 0; i < deployableSignatures.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        deployableSignatures[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );

      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), deployableSignatures[i], true);
    }

    accessConfigSystem.configureAccess(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOnline.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOnline.selector,
      true
    );
    accessConfigSystem.configureAccess(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOffline.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOffline.selector,
      true
    );
  }

  function configureEntityRecordAccess() internal {
    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecord.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecord.selector,
      true
    );

    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecordMetadata.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecordMetadata.selector,
      true
    );

    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setName.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setName.selector,
      true
    );

    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDappURL.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDappURL.selector,
      true
    );

    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDescription.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.setDescription.selector,
      true
    );
  }

  function configureStaticDataAccess() internal {
    accessConfigSystem.configureAccess(
      staticDataSystem.toResourceId(),
      StaticDataSystem.setCid.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(staticDataSystem.toResourceId(), StaticDataSystem.setCid.selector, true);

    accessConfigSystem.configureAccess(
      staticDataSystem.toResourceId(),
      StaticDataSystem.setBaseURI.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      staticDataSystem.toResourceId(),
      StaticDataSystem.setBaseURI.selector,
      true
    );
  }

  function configureEphemeralInventoryAccess() internal {
    accessConfigSystem.configureAccess(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.setEphemeralInventoryCapacity.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.setEphemeralInventoryCapacity.selector,
      true
    );

    accessConfigSystem.configureAccess(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.depositToEphemeralInventory.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.depositToEphemeralInventory.selector,
      true
    );

    accessConfigSystem.configureAccess(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.withdrawFromEphemeralInventory.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.withdrawFromEphemeralInventory.selector,
      true
    );
  }

  function configureInventoryInteractAccess() internal {
    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.ephemeralToInventoryTransfer.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwnerOrCanDepositToInventory.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.ephemeralToInventoryTransfer.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.inventoryToEphemeralTransfer.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwnerOrCanWithdrawFromInventory.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.inventoryToEphemeralTransfer.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setEphemeralToInventoryTransferAccess.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyInventoryAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setEphemeralToInventoryTransferAccess.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setInventoryToEphemeralTransferAccess.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyInventoryAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setInventoryToEphemeralTransferAccess.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setInventoryAdminAccess.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyInventoryAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setInventoryAdminAccess.selector,
      true
    );
  }

  function configureLocationAccess() internal {
    bytes4[1] memory onlyAdminSelectors = [LocationSystem.saveLocation.selector];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        locationSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );

      accessConfigSystem.setAccessEnforcement(locationSystem.toResourceId(), onlyAdminSelectors[i], true);
    }
  }

  function configureSmartCharacterAccess() internal {
    accessConfigSystem.configureAccess(
      smartCharacterSystem.toResourceId(),
      SmartCharacterSystem.registerCharacterToken.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartCharacterSystem.toResourceId(),
      SmartCharacterSystem.registerCharacterToken.selector,
      true
    );
  }

  function configureFuelAccess() internal {
    bytes4[6] memory fuelSignatures = [
      FuelSystem.configureFuelParameters.selector,
      FuelSystem.setFuelUnitVolume.selector,
      FuelSystem.setFuelConsumptionIntervalInSeconds.selector,
      FuelSystem.setFuelMaxCapacity.selector,
      FuelSystem.depositFuel.selector,
      FuelSystem.withdrawFuel.selector
    ];

    for (uint256 i = 0; i < fuelSignatures.length; i++) {
      accessConfigSystem.configureAccess(
        fuelSystem.toResourceId(),
        fuelSignatures[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );

      accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), fuelSignatures[i], true);
    }

    accessConfigSystem.configureAccess(
      fuelSystem.toResourceId(),
      FuelSystem.setFuelAmount.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableSystem.selector
    );
    accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), FuelSystem.setFuelAmount.selector, true);
  }

  function configureSmartTurretAccess() internal {
    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorSmartTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorSmartTurret.selector,
      true
    );

    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureSmartTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwner.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureSmartTurret.selector,
      true
    );
  }

  function registerSmartStorageUnitClass(bytes32 adminRole) internal {
    ResourceId[] memory systemIds = new ResourceId[](9);
    systemIds[0] = inventorySystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = ephemeralInventorySystem.toResourceId();
    systemIds[3] = inventoryInteractSystem.toResourceId();
    systemIds[4] = entityRecordSystem.toResourceId();
    systemIds[5] = smartStorageUnitSystem.toResourceId();
    systemIds[6] = smartAssemblySystem.toResourceId();
    systemIds[7] = fuelSystem.toResourceId();
    systemIds[8] = locationSystem.toResourceId();
    entitySystem.registerClass(Initialize.get(smartStorageUnitSystem.toResourceId()), systemIds);
  }

  function registerInventoryItemClass(bytes32 adminRole) internal {
    uint256 inventoryItemClassId = uint256(bytes32("INVENTORY_ITEM"));
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = inventorySystem.toResourceId();
    systemIds[1] = entityRecordSystem.toResourceId();
    systemIds[2] = ephemeralInventorySystem.toResourceId();
    entitySystem.registerClass(Initialize.get(inventorySystem.toResourceId()), systemIds);
  }

  function registerSmartCharacterClass(bytes32 adminRole) internal {
    uint256 smartCharacterClassId = uint256(bytes32("SMART_CHARACTER"));
    ResourceId[] memory systemIds = new ResourceId[](2);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = smartCharacterSystem.toResourceId();
    entitySystem.registerClass(Initialize.get(smartCharacterSystem.toResourceId()), systemIds);
  }

  function registerSmartTurretClass(bytes32 adminRole) internal {
    ResourceId[] memory smartTurretSystemIds = new ResourceId[](6);
    smartTurretSystemIds[0] = entityRecordSystem.toResourceId();
    smartTurretSystemIds[1] = smartTurretSystem.toResourceId();
    smartTurretSystemIds[2] = fuelSystem.toResourceId();
    smartTurretSystemIds[3] = locationSystem.toResourceId();
    smartTurretSystemIds[4] = deployableSystem.toResourceId();
    smartTurretSystemIds[5] = smartAssemblySystem.toResourceId();
    entitySystem.registerClass(Initialize.get(smartTurretSystem.toResourceId()), smartTurretSystemIds);
  }

  function registerSmartGateClass(bytes32 adminRole) internal {
    ResourceId[] memory smartGateSystemIds = new ResourceId[](6);
    smartGateSystemIds[0] = entityRecordSystem.toResourceId();
    smartGateSystemIds[1] = smartGateSystem.toResourceId();
    smartGateSystemIds[2] = fuelSystem.toResourceId();
    smartGateSystemIds[3] = locationSystem.toResourceId();
    smartGateSystemIds[4] = deployableSystem.toResourceId();
    smartGateSystemIds[5] = smartAssemblySystem.toResourceId();
    entitySystem.registerClass(Initialize.get(smartGateSystem.toResourceId()), smartGateSystemIds);
  }

  function configureSmartGateAccess() internal {
    accessConfigSystem.configureAccess(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorSmartGate.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorSmartGate.selector,
      true
    );

    bytes4[3] memory onlyOwnerSelectors = [
      SmartGateSystem.configureSmartGate.selector,
      SmartGateSystem.linkSmartGates.selector,
      SmartGateSystem.unlinkSmartGates.selector
    ];

    for (uint256 i = 0; i < onlyOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartGateSystem.toResourceId(),
        onlyOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDeployableOwner.selector
      );

      accessConfigSystem.setAccessEnforcement(smartGateSystem.toResourceId(), onlyOwnerSelectors[i], true);
    }
  }

  function configureInventoryAccess() internal {
    accessConfigSystem.configureAccess(
      inventorySystem.toResourceId(),
      InventorySystem.setInventoryCapacity.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventorySystem.toResourceId(),
      InventorySystem.setInventoryCapacity.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventorySystem.toResourceId(),
      InventorySystem.depositToInventory.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventorySystem.toResourceId(),
      InventorySystem.depositToInventory.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventorySystem.toResourceId(),
      InventorySystem.withdrawFromInventory.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventorySystem.toResourceId(),
      InventorySystem.withdrawFromInventory.selector,
      true
    );
  }
}
