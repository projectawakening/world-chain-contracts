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
import { inventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { ephemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { IEveSystem } from "../src/namespaces/evefrontier/interfaces/IEveSystem.sol";

contract ConfigSof is Script {
  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);

    _initializeSofAccessConfig();
    _initializeClassRegistry();
    _initializeWorldAccess(deployer);

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

    CallAccess.set(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, inventorySystem.getAddress(), true);
    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.instantiate.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );

    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.deleteObject.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      entitySystem.toResourceId(),
      IEntitySystem.deleteObject.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );

    // RoleManagementSystem.sol
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      eveSystem.getAddress(),
      true
    );
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedCreateRole.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );

    // Grant admin role to eveSystem
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      eveSystem.getAddress(),
      true
    );

    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedGrantRole.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );

    // Revoke all roles
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      eveSystem.getAddress(),
      true
    );

    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      roleManagementSystem.toResourceId(),
      IRoleManagementSystem.scopedRevokeAll.selector,
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

  function _initializeWorldAccess(address deployer) internal {
    bytes32 adminRole = bytes32("admin");
    roleManagementSystem.createRole(adminRole, adminRole);
    roleManagementSystem.grantRole(adminRole, deployer);

    eveSystem.configureEntityRecordAccess();
    eveSystem.configureStaticDataAccess();
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
