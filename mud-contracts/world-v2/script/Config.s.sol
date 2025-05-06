// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

import { IAccessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IAccessConfigSystem.sol";
import { IEntitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ITagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { IRoleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";

import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

import { eveSystem } from "../src/namespaces/evefrontier/codegen/systems/EveSystemLib.sol";
import { InventorySystem, inventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryOwnershipSystemLib.sol";
import { deployableSystem } from "../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartCharacterSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { inventoryInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { ephemeralInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { IEveSystem } from "../src/namespaces/evefrontier/interfaces/IEveSystem.sol";
import { FuelSystem, fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { smartAssemblySystem } from "../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";
import { Tenant } from "../src/namespaces/evefrontier/codegen/tables/Tenant.sol";

contract Config is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    string memory tenant = vm.envString("TENANT");
    bytes32 tenantId = keccak256(abi.encodePacked(tenant));

    vm.startBroadcast(deployerPrivateKey);

    // set world tenant
    Tenant.set(tenantId);

    _initializeSofAccessConfig();
    _initializeClassRegistry();
    _initializeWorldAccess();

    vm.stopBroadcast();
  }

  function _initializeSofAccessConfig() internal {
    // AccessConfigSystem.sol
    bytes4[2] memory functionSelectors = [
      IAccessConfigSystem.configureAccess.selector,
      IAccessConfigSystem.setAccessEnforcement.selector
    ];

    for (uint i = 0; i < functionSelectors.length; i++) {
      CallAccess.set(accessConfigSystem.toResourceId(), functionSelectors[i], eveSystem.getAddress(), true);
    }

    // EntitySystem.sol
    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.scopedRegisterClass.selector,
      eveSystem.getAddress(),
      true
    );
    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.scopedRegisterClass.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.scopedRegisterClass.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );

  }

  function _initializeClassRegistry() internal {
    eveSystem.registerSmartCharacterClass(vm.envUint("CHARACTER_TYPE_ID"), vm.envUint("CHARACTER_VOLUME"));
    eveSystem.registerSmartStorageUnitClass(vm.envUint("SSU_TYPE_ID"), vm.envUint("SSU_VOLUME"));
    eveSystem.registerSmartTurretClass(vm.envUint("TURRET_TYPE_ID"), vm.envUint("TURRET_VOLUME"));
    eveSystem.registerSmartGateClass(vm.envUint("GATE_TYPE_ID"), vm.envUint("GATE_VOLUME"));
    eveSystem.registerNetworkNodeClass(vm.envUint("NETWORK_NODE_TYPE_ID"), vm.envUint("NETWORK_NODE_VOLUME"));
  }

  function _initializeWorldAccess() internal {
    // EntityRecordSystem.sol
    CallAccess.set(entityRecordSystem.toResourceId(), EntityRecordSystem.createRecord.selector, inventorySystem.getAddress(), true);
    CallAccess.set(entityRecordSystem.toResourceId(), EntityRecordSystem.createRecord.selector, ephemeralInventorySystem.getAddress(), true);
    CallAccess.set(entityRecordSystem.toResourceId(), EntityRecordSystem.createRecord.selector, smartCharacterSystem.getAddress(), true);
    CallAccess.set(entityRecordSystem.toResourceId(), EntityRecordSystem.createRecord.selector, smartAssemblySystem.getAddress(), true);

    // InventorySystem.sol
    bytes4[2] memory inventoryFunctionSelectors = [
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];
    for (uint i = 0; i < inventoryFunctionSelectors.length; i++) {
      CallAccess.set(inventorySystem.toResourceId(), inventoryFunctionSelectors[i], inventoryInteractSystem.getAddress(), true);
      CallAccess.set(inventorySystem.toResourceId(), inventoryFunctionSelectors[i], ephemeralInteractSystem.getAddress(), true);
    }

    // EphemeralInventorySystem.sol
    bytes4[2] memory ephemeralInventoryFunctionSelectors = [
      EphemeralInventorySystem.depositEphemeral.selector,
      EphemeralInventorySystem.withdrawEphemeral.selector
    ];
    for (uint i = 0; i < ephemeralInventoryFunctionSelectors.length; i++) {
      CallAccess.set(ephemeralInventorySystem.toResourceId(), ephemeralInventoryFunctionSelectors[i], inventoryInteractSystem.getAddress(), true);
      CallAccess.set(ephemeralInventorySystem.toResourceId(), ephemeralInventoryFunctionSelectors[i], ephemeralInteractSystem.getAddress(), true);
    }

    // OwnershipSystem.sol
    bytes4[2] memory ownershipInventoryFunctionSelectors = [
      InventoryOwnershipSystem.assignItemToInventory.selector,
      InventoryOwnershipSystem.removeItemFromInventory.selector
    ];
    for (uint i = 0; i < ownershipInventoryFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystem.toResourceId(), ownershipInventoryFunctionSelectors[i], inventorySystem.getAddress(), true);
      CallAccess.set(ownershipSystem.toResourceId(), ownershipInventoryFunctionSelectors[i], ephemeralInventorySystem.getAddress(), true);
    }
    bytes4[2] memory ownershipAccountFunctionSelectors = [
      OwnershipSystem.assignOwner.selector,
      OwnershipSystem.removeOwner.selector
    ];
    for (uint i = 0; i < ownershipAccountFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystem.toResourceId(), ownershipAccountFunctionSelectors[i], deployableSystem.getAddress(), true);
      CallAccess.set(ownershipSystem.toResourceId(), ownershipAccountFunctionSelectors[i], smartCharacterSystem.getAddress(), true);
    }
    CallAccess.set(ownershipSystem.toResourceId(), OwnershipSystem.assignOwner.selector, ephemeralInventorySystem.getAddress(), true);


    bytes32 adminRole = bytes32("admin");
    roleManagementSystem.createRole(adminRole, adminRole); // this auto-grants the role to the caller (deployer)

    eveSystem.configureEntityRecordAccess();
    eveSystem.configureFuelAccess();
    eveSystem.configureLocationAccess();
    eveSystem.configureNetworkNodeAccess();
    eveSystem.configureDeployableAccess();
    eveSystem.configureSmartAssemblyAccess();
    eveSystem.configureInventoryAccess();
    eveSystem.configureEphemeralInventoryAccess();
    eveSystem.configureInventoryInteractAccess();
    eveSystem.configureSmartCharacterAccess();
    eveSystem.configureSmartStorageUnitAccess();
    eveSystem.configureSmartTurretAccess();
    eveSystem.configureSmartGateAccess();
    eveSystem.configureEphemeralInteractAccess();
    eveSystem.configureInventoryInteractAccess();
    eveSystem.configureKillMailAccess();
    eveSystem.configureOwnershipAccess();
  }
}
