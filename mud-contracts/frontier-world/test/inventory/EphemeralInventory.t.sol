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

import { EphemeralInventoryTable } from "../../src/codegen/tables/EphemeralInventoryTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";

import { Utils } from "../../src/modules/inventory/Utils.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

contract InventoryTest is Test {
  using Utils for bytes14;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  InventoryLib.World ephemeralInventory;
  InventoryModule inventoryModule;

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    inventoryModule = new InventoryModule();
    baseWorld.installModule(inventoryModule, abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    ephemeralInventory = InventoryLib.World(baseWorld, DEPLOYMENT_NAMESPACE);
  }

  function testSetup() public {
    address EpheremalSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(EpheremalSystem);
    assertEq(ephemeralInventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testSetEphemeralInventoryCapacity(uint256 smartObjectId, address owner, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    vm.assume(owner != address(0));

    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);
    assertEq(
      EphemeralInventoryTable.getCapacity(DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(), smartObjectId, owner),
      storageCapacity
    );
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, address owner, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.EphemeralInventory_InvalidCapacity.selector,
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      )
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);
  }
}
