
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceAccess } from "@latticexyz/world/src/codegen/tables/ResourceAccess.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils as InventoryUtils } from "../src/modules/inventory/Utils.sol";

import { AccessRole, AccessRolePerSys, AccessEnforcement } from "../src/codegen/index.sol";
import {ADMIN, APPROVED } from "../src/modules/access/constants.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";

contract InventoryAccess is Script {
  using AccessUtils for bytes14;
  using InventoryUtils for bytes14;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);


    address[] memory adminAccounts = vm.envAddress("ADMIN_ACCOUNTS", ",");
    // populate with ALL active ADMIN public addresses
    address[] memory adminAccessList = new address[](adminAccounts.length);
    
    for (uint i = 0; i < adminAccounts.length; i++) {
      adminAccessList[i] = adminAccounts[i];
    }

    // assumes the current vm.privkey (deployer) is the eveworld namespace owner
    // if no access, grant self access to each resource allowing for Access configuration access
    if(!ResourceAccess.get(AccessRole._tableId, deployer)) {
      world.grantAccess(AccessRole._tableId, deployer);
    }
    if(!ResourceAccess.get(AccessRolePerSys._tableId, deployer)) {
      world.grantAccess(AccessRolePerSys._tableId, deployer);
    }
    if(!ResourceAccess.get(AccessEnforcement._tableId, deployer)) {
      world.grantAccess(AccessEnforcement._tableId, deployer);
    }

    address[] memory approvedAccessList = new address[](1);
    // currently we are only allowing InventoryInteract to be an APPROVED call forwarder to the Inventory and EphemeralInventory systems
    address interactAddr = Systems.getSystem(WORLD_NAMESPACE.inventoryInteractSystemId());
    approvedAccessList[0] = interactAddr;
    // set global access list for ADMIN accounts
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessListByRole, (ADMIN, adminAccessList)));
    // set access list APPROVED accounts for the InventorySystem
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessListPerSystemByRole, (WORLD_NAMESPACE.inventorySystemId(), APPROVED, approvedAccessList)));
    // set access list APPROVED accounts for the EphemeralInventorySystem
    world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessListPerSystemByRole, (WORLD_NAMESPACE.ephemeralInventorySystemId(), APPROVED, approvedAccessList)));
  
  }
}