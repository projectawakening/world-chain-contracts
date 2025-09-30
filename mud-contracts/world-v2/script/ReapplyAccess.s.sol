// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { CallAccess } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/tables/CallAccess.sol";

import { InventorySystem, inventorySystem } from "../src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../src/namespaces/evefrontier/codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryOwnershipSystemLib.sol";
import { deployableSystem } from "../src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartCharacterSystem } from "../src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { inventoryInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { ephemeralInteractSystem } from "../src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { FuelSystem, fuelSystem } from "../src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { smartAssemblySystem } from "../src/namespaces/evefrontier/codegen/systems/SmartAssemblySystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../src/namespaces/evefrontier/codegen/systems/EntityRecordSystemLib.sol";

contract ReapplyAccess is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    _reapplyAccess();

    vm.stopBroadcast();
  }

  function _reapplyAccess() internal {
    // EntityRecordSystem.sol
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      inventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      smartCharacterSystem.getAddress(),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      smartAssemblySystem.getAddress(),
      true
    );
    CallAccess.set(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      fuelSystem.getAddress(),
      true
    );

    // InventorySystem.sol
    bytes4[2] memory inventoryFunctionSelectors = [
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];
    for (uint i = 0; i < inventoryFunctionSelectors.length; i++) {
      CallAccess.set(
        inventorySystem.toResourceId(),
        inventoryFunctionSelectors[i],
        inventoryInteractSystem.getAddress(),
        true
      );
      CallAccess.set(
        inventorySystem.toResourceId(),
        inventoryFunctionSelectors[i],
        ephemeralInteractSystem.getAddress(),
        true
      );
    }

    // EphemeralInventorySystem.sol
    bytes4[2] memory ephemeralInventoryFunctionSelectors = [
      EphemeralInventorySystem.depositEphemeral.selector,
      EphemeralInventorySystem.withdrawEphemeral.selector
    ];
    for (uint i = 0; i < ephemeralInventoryFunctionSelectors.length; i++) {
      CallAccess.set(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryFunctionSelectors[i],
        inventoryInteractSystem.getAddress(),
        true
      );
      CallAccess.set(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryFunctionSelectors[i],
        ephemeralInteractSystem.getAddress(),
        true
      );
    }

    // OwnershipSystem.sol
    bytes4[2] memory ownershipInventoryFunctionSelectors = [
      InventoryOwnershipSystem.assignItemToInventory.selector,
      InventoryOwnershipSystem.removeItemFromInventory.selector
    ];
    for (uint i = 0; i < ownershipInventoryFunctionSelectors.length; i++) {
      CallAccess.set(
        ownershipSystem.toResourceId(),
        ownershipInventoryFunctionSelectors[i],
        inventorySystem.getAddress(),
        true
      );
      CallAccess.set(
        ownershipSystem.toResourceId(),
        ownershipInventoryFunctionSelectors[i],
        ephemeralInventorySystem.getAddress(),
        true
      );
    }
    bytes4[2] memory ownershipAccountFunctionSelectors = [
      OwnershipSystem.assignOwner.selector,
      OwnershipSystem.removeOwner.selector
    ];
    for (uint i = 0; i < ownershipAccountFunctionSelectors.length; i++) {
      CallAccess.set(
        ownershipSystem.toResourceId(),
        ownershipAccountFunctionSelectors[i],
        deployableSystem.getAddress(),
        true
      );
      CallAccess.set(
        ownershipSystem.toResourceId(),
        ownershipAccountFunctionSelectors[i],
        smartCharacterSystem.getAddress(),
        true
      );
    }
    CallAccess.set(
      ownershipSystem.toResourceId(),
      OwnershipSystem.assignOwner.selector,
      ephemeralInventorySystem.getAddress(),
      true
    );
  }
}
