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

import "@eveworld/common-constants/src/constants.sol";
import { SmartObjectFrameworkModule } from "@eveworld/frontier-smart-object-framework/src/SmartObjectFrameworkModule.sol";
import { EntityCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/EntityCore.sol";
import { HookCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/HookCore.sol";
import { ModuleCore } from "@eveworld/frontier-smart-object-framework/src/systems/core/ModuleCore.sol";

import { ModulesInitializationLibrary } from "../../src/utils/ModulesInitializationLibrary.sol";
import { SOFInitializationLibrary } from "@eve/frontier-smart-object-framework/src/SOFInitializationLibrary.sol";
import { SmartObjectLib } from "@eve/frontier-smart-object-framework/src/SmartObjectLib.sol";
import { CLASS, OBJECT } from "@eve/frontier-smart-object-framework/src/constants.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { EphemeralInvTable, EphemeralInvTableData } from "../../src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvCapacityTable } from "../../src/codegen/tables/EphemeralInvCapacityTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";
import { InventoryInteract } from "../../src/modules/inventory/systems/InventoryInteract.sol";
import { InventoryItem } from "../../src/modules/inventory/types.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { EntityRecordModule } from "../../src/modules/entity-record/EntityRecordModule.sol";
import { StaticDataModule } from "../../src/modules/static-data/StaticDataModule.sol";
import { LocationModule } from "../../src/modules/location/LocationModule.sol";
import { SmartDeployableModule } from "../../src/modules/smart-deployable/SmartDeployableModule.sol";
import { SmartDeployableLib } from "../../src/modules/smart-deployable/SmartDeployableLib.sol";
import { SmartDeployable } from "../../src/modules/smart-deployable/systems/SmartDeployable.sol";
import { EntityRecordLib } from "../../src/modules/entity-record/EntityRecordLib.sol";
import { registerERC721 } from "../../src/modules/eve-erc721-puppet/registerERC721.sol";
import { IERC721Mintable } from "../../src/modules/eve-erc721-puppet/IERC721Mintable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { StaticDataGlobalTableData } from "../../src/codegen/tables/StaticDataGlobalTable.sol";
import { Utils as CoreUtils } from "@eve/frontier-smart-object-framework/src/utils.sol";
import { EntityTable } from "@eve/frontier-smart-object-framework/src/codegen/tables/EntityTable.sol";

import { Inventory } from "../../src/modules/inventory/systems/Inventory.sol";
import { EphemeralInventory } from "../../src/modules/inventory/systems/EphemeralInventory.sol";

import { InventoryItem } from "../../src/modules/inventory/types.sol";

contract EphemeralInventoryTest is Test {
  using Utils for bytes14;
  using CoreUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using ModulesInitializationLibrary for IBaseWorld;
  using SOFInitializationLibrary for IBaseWorld;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using InventoryLib for InventoryLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  IERC721Mintable erc721DeployableToken;
  SmartObjectLib.World smartObject;
  EntityRecordLib.World entityRecord;
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
    world.initSOF();
    smartObject = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);

    // install module dependancies
    _installModule(new PuppetModule(), 0);
    _installModule(new StaticDataModule(), STATIC_DATA_DEPLOYMENT_NAMESPACE);
    _installModule(new EntityRecordModule(), ENTITY_RECORD_DEPLOYMENT_NAMESPACE);
    _installModule(new LocationModule(), LOCATION_DEPLOYMENT_NAMESPACE);
    world.initStaticData();
    world.initEntityRecord();
    world.initLocation();
    entityRecord = EntityRecordLib.World(world, ENTITY_RECORD_DEPLOYMENT_NAMESPACE);

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
    world.initSmartDeployable();

    smartObject.registerEntity(SMART_DEPLOYABLE_CLASS_ID, CLASS);
    world.associateClassIdToSmartDeployable(SMART_DEPLOYABLE_CLASS_ID);
    smartDeployable = SmartDeployableLib.World(world, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE);
    smartDeployable.registerDeployableToken(address(erc721DeployableToken));
    smartDeployable.globalResume();

    // Inventory Module installation
    inventoryModule = new InventoryModule();
    if (NamespaceOwner.getOwner(WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE)) == address(this))
      world.transferOwnership(
        WorldResourceIdLib.encodeNamespace(INVENTORY_DEPLOYMENT_NAMESPACE),
        address(inventoryModule)
      );

    world.installModule(
      inventoryModule,
      abi.encode(INVENTORY_DEPLOYMENT_NAMESPACE, new Inventory(), new EphemeralInventory(), new InventoryInteract())
    );
    world.initInventory();
    ephemeralInventory = InventoryLib.World(world, INVENTORY_DEPLOYMENT_NAMESPACE);

    _createMockItems();
  }

  function _createMockItems() internal {
    //Mock Item creation
    smartObject.registerEntity(4235, OBJECT);
    world.associateEntityRecord(4235);
    entityRecord.createEntityRecord(4235, 4235, 12, 100);
    smartObject.registerEntity(4236, OBJECT);
    world.associateEntityRecord(4236);
    entityRecord.createEntityRecord(4236, 4236, 12, 200);
    smartObject.registerEntity(4237, OBJECT);
    world.associateEntityRecord(4237);
    entityRecord.createEntityRecord(4237, 4237, 12, 150);
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

  function testSetDeployableStateToValid(uint256 smartObjectId) public {
    vm.assume(
      smartObjectId != 0 &&
        !EntityTable.getDoesExists(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(), smartObjectId)
    );

    DeployableState.set(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId,
      DeployableStateData({
        createdAt: block.timestamp,
        previousState: State.ANCHORED,
        currentState: State.ONLINE,
        isValid: true,
        anchoredAt: block.timestamp,
        updatedBlockNumber: block.number,
        updatedBlockTime: block.timestamp
      })
    );
  }

  function testSetEphemeralInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(
      smartObjectId != 0 &&
        !EntityTable.getDoesExists(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(), smartObjectId)
    );
    vm.assume(storageCapacity != 0);

    smartObject.registerEntity(smartObjectId, OBJECT);
    world.associateInventory(smartObjectId);

    DeployableState.setCurrentState(
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.deployableStateTableId(),
      smartObjectId,
      State.ONLINE
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, storageCapacity);
    assertEq(
      EphemeralInvCapacityTable.getCapacity(
        INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvCapacityTableId(),
        smartObjectId
      ),
      storageCapacity
    );
  }

  function testRevertSetInventoryCapacity(uint256 smartObjectId, uint256 storageCapacity) public {
    vm.assume(storageCapacity == 0);
    vm.assume(
      smartObjectId != 0 &&
        !EntityTable.getDoesExists(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(), smartObjectId)
    );

    smartObject.registerEntity(smartObjectId, OBJECT);
    world.associateInventory(smartObjectId);

    vm.expectRevert(
      abi.encodeWithSelector(
        IInventoryErrors.Inventory_InvalidCapacity.selector,
        "InventoryEphemeralSystem: storage capacity cannot be 0"
      )
    );
    ephemeralInventory.setEphemeralInventoryCapacity(smartObjectId, storageCapacity);
  }

  function testDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(
      smartObjectId != 0 &&
        !EntityTable.getDoesExists(SMART_OBJECT_DEPLOYMENT_NAMESPACE.entityTableTableId(), smartObjectId)
    );
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1000 && storageCapacity <= 10000);

    testSetDeployableStateToValid(smartObjectId);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, address(1), 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, address(2), 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, address(3), 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
      smartObjectId,
      owner
    );
    uint256 capacityBeforeDeposit = inventoryTableData.usedCapacity;
    uint256 capacityAfterDeposit = 0;

    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    inventoryTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
      smartObjectId,
      owner
    );

    //Check weather the items are stored in the inventory table
    for (uint256 i = 0; i < items.length; i++) {
      uint256 itemVolume = items[i].volume * items[i].quantity;
      capacityAfterDeposit += itemVolume;
      assertEq(inventoryTableData.items[i], items[i].inventoryItemId);
    }

    inventoryTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
      smartObjectId,
      owner
    );
    assert(capacityBeforeDeposit < capacityAfterDeposit);
  }

  function testEphemeralInventoryItemQuantityIncrease(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 20000 && storageCapacity <= 50000);

    testSetDeployableStateToValid(smartObjectId);
    //Note: Issue applying fuzz testing for the below array of inputs : https://github.com/foundry-rs/foundry/issues/5343
    InventoryItem[] memory items = new InventoryItem[](3);
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 3);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 2);

    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);

    //check the increase in quantity
    ephemeralInventory.depositToEphemeralInventory(smartObjectId, owner, items);
    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, items[0].quantity * 2);
    assertEq(inventoryItem2.quantity, items[1].quantity * 2);
    assertEq(inventoryItem3.quantity, items[2].quantity * 2);
  }

  function testRevertDepositToEphemeralInventory(uint256 smartObjectId, uint256 storageCapacity, address owner) public {
    vm.assume(smartObjectId != 0);
    vm.assume(owner != address(0));
    vm.assume(storageCapacity >= 1 && storageCapacity <= 500);
    testSetEphemeralInventoryCapacity(smartObjectId, storageCapacity);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(1), 4235, 0, 100, 6);

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
    items[0] = InventoryItem(4235, owner, 4235, 0, 100, 1);
    items[1] = InventoryItem(4236, owner, 4236, 0, 200, 2);
    items[2] = InventoryItem(4237, owner, 4237, 0, 150, 1);

    EphemeralInvTableData memory inventoryTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
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

    inventoryTableData = EphemeralInvTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInvTableId(),
      smartObjectId,
      owner
    );
    assertEq(inventoryTableData.usedCapacity, capacityBeforeWithdrawal - capacityAfterWithdrawal);

    uint256[] memory existingItems = inventoryTableData.items;
    assertEq(existingItems.length, 2);
    assertEq(existingItems[0], items[0].inventoryItemId);
    assertEq(existingItems[1], items[2].inventoryItemId);

    //Check weather the items quantity is reduced
    EphemeralInvItemTableData memory inventoryItem1 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[0].inventoryItemId,
      items[0].owner
    );
    EphemeralInvItemTableData memory inventoryItem2 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[1].inventoryItemId,
      items[1].owner
    );
    EphemeralInvItemTableData memory inventoryItem3 = EphemeralInvItemTable.get(
      INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      items[2].inventoryItemId,
      items[2].owner
    );
    assertEq(inventoryItem1.quantity, 2);
    assertEq(inventoryItem2.quantity, 0);
    assertEq(inventoryItem3.quantity, 1);
  }

  function testRevertWithdrawFromEphemeralInventory(
    uint256 smartObjectId,
    uint256 storageCapacity,
    address owner
  ) public {
    testDepositToEphemeralInventory(smartObjectId, storageCapacity, owner);

    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem(4235, address(1), 4235, 0, 100, 6);

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
