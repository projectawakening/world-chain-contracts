// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { CallAccess } from "../src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

import { IAccessConfigSystem} from "../src/namespaces/evefrontier/interfaces/IAccessConfigSystem.sol";
import { IEntitySystem } from "../src/namespaces/evefrontier/interfaces/IEntitySystem.sol";
import { ITagSystem } from "../src/namespaces/evefrontier/interfaces/ITagSystem.sol";
import { IRoleManagementSystem } from "../src/namespaces/evefrontier/interfaces/IRoleManagementSystem.sol";

import { accessConfigSystem } from "../src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { entitySystem } from "../src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { tagSystem } from "../src/namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { roleManagementSystem } from "../src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";

// import { eveSystem } from "../src/namespaces/evefrontier/world-system-libs/EveSystemLib.sol";
// import { inventorySystem } from "../src/namespaces/evefrontier/world-system-libs/InventorySystemLib.sol";
// import { ephemeralInventorySystem } from "../src/namespaces/evefrontier/world-system-libs/EphemeralInventorySystemLib.sol";

contract SetSOFCallAccess is Script {

  function run(address worldAddress) public {
    IWorldKernel world = IWorldKernel(worldAddress);
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    vm.startBroadcast(deployerPrivateKey);

    // AccessConfigSystem.sol
    // CallAccess.set(accessConfigSystem.toResourceId(), IAccessConfigSystem.configureAccess.selector, eveSystem.getAddress), true);
    // CallAccess.set(accessConfigSystem.toResourceId(), IAccessConfigSystem.setAccessEnforcement.selector, eveSystem.getAddress(), true);

    // TagSystem.sol
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.setTag.selector, entitySystem.getAddress(), true);
    CallAccess.set(tagSystem.toResourceId(), ITagSystem.removeTag.selector, entitySystem.getAddress(), true);

    // EntitySystem.sol
    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, eveSystem.getAddress(), true);
    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.scopedRegisterClass.selector, ephemeralInventorySystem.getAddress(), true);

    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.instantiate.selector, ephemeralInventorySystem.getAddress(), true);

    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(entitySystem.toResourceId(), IEntitySystem.deleteObject.selector, ephemeralInventorySystem.getAddress(), true);
    
    // RoleManagementSystem.sol
    CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedCreateRole.selector, entitySystem.getAddress(), true);
    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedCreateRole.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedCreateRole.selector, ephemeralInventorySystem.getAddress(), true);

    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedGrantRole.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedGrantRole.selector, ephemeralInventorySystem.getAddress(), true);

    CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedRevokeAll.selector, entitySystem.getAddress(), true);
    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedRevokeAll.selector, inventorySystem.getAddress(), true);
    // CallAccess.set(roleManagementSystem.toResourceId(), IRoleManagementSystem.scopedRevokeAll.selector, ephemeralInventorySystem.getAddress(), true);

    vm.stopBroadcast();
  }
}