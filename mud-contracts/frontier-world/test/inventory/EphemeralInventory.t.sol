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
import { PuppetModule } from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { IModule } from "@latticexyz/world/src/IModule.sol";

import "@eve/common-constants/src/constants.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EphemeralInventoryTable } from "../../src/codegen/tables/EphemeralInventoryTable.sol";
import { EphemeralInventoryTableData } from "../../src/codegen/tables/EphemeralInventoryTable.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";

import { SmartObjectFrameworkModule } from "@eve/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eve/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eve/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eve/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";

import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";

import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";

import { InventoryItem } from "../../src/modules/inventory/types.sol";

contract EphemeralInventoryTest is Test {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  IERC721Mintable erc721DeployableToken;
  InventoryLib.World ephemeralInventory;
  SmartDeployableLib.World smartDeployable;
  InventoryModule inventoryModule;

  bytes14 constant ERC721_DEPLOYABLE = "DeployableTokn";

  function setUp() public {
    world = IBaseWorld(address(new World()));
    world.initialize(createCoreModule());
    // required for `NamespaceOwner` and `WorldResourceIdLib` to infer current World Address properly
    StoreSwitch.setStoreAddress(address(world));

    // installing SOF & other modules (SmartCharacterModule dependancies)
    world.installModule(
      new SmartObjectFrameworkModule(),
      abi.encode(SMART_OBJECT_DEPLOYMENT_NAMESPACE, new EntityCore(), new HookCore(), new ModuleCore())
    );
    // install module dependancies
    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);

    erc721DeployableToken = registerERC721(
      world,
      ERC721_DEPLOYABLE,
      StaticDataGlobalTableData({ name: "SmartDeployable", symbol: "SD", baseURI: "" })
    );
    // install SmartDeployableModule
    SmartDeployableModule deployableModule = new SmartDeployableModule();
    if (
      NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE)) ==
      address(this)
    )
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE),
        address(deployableModule)
      );
    world.installModule(deployableModule, abi.encode(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, new SmartDeployable()));
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721DeployableToken));

    // Inventory Module installation
    inventoryModule = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE),
        address(inventoryModule)
      );

    world.installModule(
      inventoryModule,
      abi.encode(INVENTORY_DEPLOYMENT_NAMESPACE, new Inventory(), new EphemeralInventory())
    );

    ephemeralInventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);

    //Mock Item creation
    // Note: this only works because the test contract currently owns `ENTITY_RECORD` namespace so direct calls to its tables are allowed
    EntityRecordTable.set(ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 4235, 4235, 12, 100);
    EntityRecordTable.set(ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 4236, 4236, 12, 200);
    EntityRecordTable.set(ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordTableId(), 4237, 4237, 12, 150);
  }

  // helper function to guard against multiple module registrations on the same namespace
  // TODO: Those kind of functions are used across all unit tests, ideally it should be inherited from a base Test contract
  function _installModule(IModule module, bytes14 namespace) internal {
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(namespace)) == address(this))
      world.transferOwnership(WorldResourceIdLib.encodeNamespace(namespace), address(module));
    world.installModule(module, abi.encode(namespace));
  }

  function testSetup() public {
    address EpheremalSystem = Systems.getSystem(INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(EpheremalSystem);
    assertEq(ephemeralInventorySystemId.getNamespace(), INVENTORY_DEPLOYMENT_NAMESPACE);
  }

  function testSetEphemeralInventoryCapacity(uint256 smartObjectId, address owner, uint256 storageCapacity) public {
    vm.assume(smartObjectId != 0);
    vm.assume(storageCapacity != 0);
    vm.assume(owner != address(0));

    DeployableState.setState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId,
      State.ONLINE
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);
    assertEq(
      EphemeralInventoryTable.getCapacity(
        INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
        smartObjectId,
        owner
      ),
      storageCapacity
    );
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, address owner, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      )
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);
  }

  function testDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1000 && storageCapacity <= 10000);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);

    EphemeralInventoryTableData memory inventoryTableData = EphemeralInventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
      smartObjectId,
      owner
    );
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    inventoryTableData = EphemeralInventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
      smartObjectId,
      owner
    );

    //Check weather the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryTableData.items[i], items[i].inventoryItemId);
    }

    inventoryTableData = EphemeralInventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
      smartObjectId,
      owner
    );
    assert(capacityBeforeDeposit < capacityAfterDeposit);
  }

  function testRevertDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1 && storageCapacity <= 500);
    testSetEphemeralInventoryCapacity(smartObjectId, owner, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InsufficientCapacity.selector,
        "InventoryEphemeralSystem: insufficient capacity",
        storageCapacity,
        items[0].volume * items[0].quantity
      )
    );
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);
  }

  function testWithdrawFromEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(owner != address(0));
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 1);
    items[1] = InventoryItem(4236, address(1), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(2), 4237, 0, 150, 1);

    EphemeralInventoryTableData memory inventoryTableData = EphemeralInventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
      smartObjectId,
      owner
    );

    uint256 capacityBeforeWithdrawal = inventoryTableData.usedCapacity;
    uint256 capacityAfterWithdrawal = 0;
    assertEq(capacityBeforeWithdrawal, 1000);

    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterWithdrawal += itemVolume;
    }

    inventoryTableData = EphemeralInventoryTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryTableId(),
      smartObjectId,
      owner
    );
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);
    assertEq(existingItems[0], items[0].inventoryItemId);
    assertEq(existingItems[1], items[2].inventoryItemId);
  }

  function testRevertWithdrawFromEphemeralInventory(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(0), 4235, 0, 100, 6);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidQuantity.selector,
        "InventoryEphemeralSystem: invalid quantity",
        3,
        items[0].quantity
      )
    );
    ephemeralInventory.withdrawFromEphemeralInventory(smartObjectId, owner, items);
  }

  function testOnlyAdminCanSetEphemeralInventoryCapacity(
    uint256 smartObjectId,
    address owner,
    uint256 storageCapacity
  ) public {
    //TODO: Implement the logic to check if the caller is admin after RBAC implementation
  }

  function testAnyoneCanDepositToInventory() public {
    //TODO : Add test case for only owner can withdraw from inventory after RBAC
  }

  function testOnlyItemOwnerCanWithdrawFromInventory() public {
    //TODO : Add test case for only owner can withdraw from inventory after RBAC
  }
}
