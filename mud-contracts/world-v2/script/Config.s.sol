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

import { EveSystemLib, eveSystem } from "../src/namespaces/evefrontier/codegen/systems/EveSystemLib.sol";
import { InventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { inventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { ephemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { OwnershipSystem } from "../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { ownershipSystem } from "../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { deployableSystem } from "../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartCharacterSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { inventoryInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { ephemeralInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { IEveSystem } from "../src/namespaces/evefrontier/interfaces/IEveSystem.sol";
import { FuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

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
    eveSystem.registerSmartCharacterClass(vm.envUint("CHARACTER_TYPE_ID"));
    eveSystem.registerSmartStorageUnitClass(vm.envUint("SSU_TYPE_ID"));
    eveSystem.registerSmartTurretClass(vm.envUint("TURRET_TYPE_ID"));
    eveSystem.registerSmartGateClass(vm.envUint("GATE_TYPE_ID"));
  }

  function _initializeWorldAccess() internal {
    // FuelSystem.sol
    bytes4[2] memory fuelFunctionSelectors = [
      FuelSystem.updateFuel.selector,
      FuelSystem.setFuelAmount.selector
    ];
    for (uint i = 0; i < fuelFunctionSelectors.length; i++) {
      CallAccess.set(fuelSystem.toResourceId(), fuelFunctionSelectors[i], deployableSystem.getAddress(), true);
    }

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
    bytes4[3] memory ownershipInventoryFunctionSelectors = [
      OwnershipSystem.ascribeToInventory.selector,
      OwnershipSystem.annulFromInventory.selector,
      OwnershipSystem.transferInventory.selector
    ];
    for (uint i = 0; i < ownershipInventoryFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystem.toResourceId(), ownershipInventoryFunctionSelectors[i], inventorySystem.getAddress(), true);
      CallAccess.set(ownershipSystem.toResourceId(), ownershipInventoryFunctionSelectors[i], ephemeralInventorySystem.getAddress(), true);
    }

    bytes4[2] memory ownershipAccountFunctionSelectors = [
      OwnershipSystem.ascribeToAccount.selector,
      OwnershipSystem.annulFromAccount.selector
    ];
    for (uint i = 0; i < ownershipAccountFunctionSelectors.length; i++) {
      CallAccess.set(ownershipSystem.toResourceId(), ownershipAccountFunctionSelectors[i], deployableSystem.getAddress(), true);
      CallAccess.set(ownershipSystem.toResourceId(), ownershipAccountFunctionSelectors[i], smartCharacterSystem.getAddress(), true);
    }

    CallAccess.set(ownershipSystem.toResourceId(), OwnershipSystem.ascribeToAccount.selector, ephemeralInventorySystem.getAddress(), true);

    bytes32 adminRole = bytes32("admin");
    roleManagementSystem.createRole(adminRole, adminRole);

    eveSystem.configureEntityRecordAccess();
    eveSystem.configureFuelAccess();
    eveSystem.configureLocationAccess();
    eveSystem.configureDeployableAccess();
    eveSystem.configureSmartAssemblyAccess();
    eveSystem.configureInventoryAccess();
    eveSystem.configureEphemeralInventoryAccess();
    eveSystem.configureInventoryInteractAccess();
    eveSystem.configureSmartCharacterAccess();
    eveSystem.configureSmartStorageUnitAccess();
    eveSystem.configureSmartTurretAccess();
    eveSystem.configureSmartGateAccess();
  }
}
