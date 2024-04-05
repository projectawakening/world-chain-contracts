// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { InventoryTable } from "../../src/codegen/tables/InventoryTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { Utils } from "../../src/modules/inventory/Utils.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { createCoreModule } from "../CreateCoreModule.sol";
import { InventoryItem } from "../../src/modules/types.sol";

contract InventoryTest is Test {
  using Utils for bytes14;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  InventoryLib.World inventory;
  InventoryModule inventoryModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    inventoryModule = new InventoryModule();
    baseWorld.installModule(inventoryModule, abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    inventory = InventoryLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address InventorySystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.inventorySystemId());
    ResourceId inventorySystemId = SystemRegistry.get(InventorySystem);
    assertEq(inventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);

    inventory.setInventoryCapacity(smartObjectId, storageCapacity);
    assertEq(InventoryTable.getCapacity(DEPLOYMENT_NAMESPACE.inventoryTableId(), smartObjectId), storageCapacity);
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "InventorySystem: storage capacity cannot be 0"
      )
    );
    inventory.setInventoryCapacity(smartObjectId, storageCapacity);
  }

  function testDepositToInventory(uint256 smartObjectId, InventoryItem[] memory items) public {
    vm.assume(smartObjectId != 0);
    vm.assume(items.length > 0);

    inventory.depositToInventory(smartObjectId, items);
  }
}
