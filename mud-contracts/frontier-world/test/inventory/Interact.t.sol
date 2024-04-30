// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "forge-std/Test.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { World } from "@latticexyz/world/src/World.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { RESOURCE_TABLE, RESOURCE_SYSTEM, RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";
import { INVENTORY_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE, FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";

import { DeployableState, DeployableStateData } from "../../src/codegen/tables/DeployableState.sol";
import { EntityRecordTable, EntityRecordTableData } from "../../src/codegen/tables/EntityRecordTable.sol";
import { InventoryItemTableData, InventoryItemTable } from "../../src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInventoryTable } from "../../src/codegen/tables/EphemeralInventoryTable.sol";
import { EphemeralInventoryTableData } from "../../src/codegen/tables/EphemeralInventoryTable.sol";
import { EphemeralInvItemTable, EphemeralInvItemTableData } from "../../src/codegen/tables/EphemeralInvItemTable.sol";
import { ItemTransferOffchainTable } from "../../src/codegen/tables/ItemTransferOffchainTable.sol";
import { IInventoryErrors } from "../../src/modules/inventory/IInventoryErrors.sol";
import { IWorld } from "../../src/codegen/world/IWorld.sol";

import { Utils as SmartDeployableUtils } from "../../src/modules/smart-deployable/Utils.sol";
import { Utils as EntityRecordUtils } from "../../src/modules/entity-record/Utils.sol";
import { State } from "../../src/modules/smart-deployable/types.sol";
import { Utils } from "../../src/modules/inventory/Utils.sol";
import { InventoryLib } from "../../src/modules/inventory/InventoryLib.sol";
import { InventoryModule } from "../../src/modules/inventory/InventoryModule.sol";
import { createCoreModule } from "../CreateCoreModule.sol";

import { InventoryItem } from "../../src/modules/types.sol";

contract VendingMachineTestSystem is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using Utils for bytes14;

  /**
   * @notice Handle the interaction flow for vending machine to exchange 2x:10y items between two players
   * @dev Ideally the ration can be configured in a seperate function and stored on-chain
   * //TODO this function needs to be authorized by the builder to access inventory functions through RBAC
   * @param smartObjectId The smart object id of the smart storage unit
   * @param inventoryOwner The owner of the inventory
   * @param quantity is the quanity of the item to be exchanged
   */
  function interactHandler(uint256 smartObjectId, address inventoryOwner, uint256 quantity) public {
    //NOTE: Store the IN and OUT item details in table by configuring in a seperate function.
    //Its hardcoded only for testing purpose
    //Inventory Item IN data
    uint256 inItemId = uint256(keccak256(abi.encode("item:46")));
    uint256 outItemId = uint256(keccak256(abi.encode("item:45")));
    uint256 ratio = 1;
    address ephItemOwner = address(0); //Ideally this should the msg.sender

    //Below Data should be stored in a table and fetched from there
    InventoryItem[] memory inItems = new InventoryItem[](1);
    inItems[0] = InventoryItem(inItemId, ephItemOwner, 46, 2, 70, quantity * ratio);

    InventoryItem[] memory outItems = new InventoryItem[](1);
    outItems[0] = InventoryItem(outItemId, inventoryOwner, 45, 1, 50, quantity * ratio);

    // Check the player has enough items in the ephemeral inventory to exchange
    EphemeralInvItemTableData memory ephemeralInvItem = EphemeralInvItemTable.get(
      DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      inItemId,
      ephItemOwner
    );
    if (ephemeralInvItem.quantity < quantity) {
      revert("Not enough item quantity to exchange");
    }

    //Check if there is enough items in the inventory

    //Withdraw from ephemeralnventory and deposit to inventory
    _inventoryLib().withdrawFromEphemeralInventory(smartObjectId, inventoryOwner, inItems);
    _inventoryLib().depositToInventory(smartObjectId, inItems);

    //Withdraw from inventory and deposit to ephemeral inventory
    _inventoryLib().withdrawFromInventory(smartObjectId, outItems);
    _inventoryLib().depositToEphemeralInventory(smartObjectId, inventoryOwner, outItems);

    //In Item owner change
    ItemTransferOffchainTable.set(
      DEPLOYMENT_NAMESPACE.itemTransferTableId(),
      smartObjectId,
      inItemId,
      ephItemOwner,
      inventoryOwner,
      inItems[0].quantity,
      block.timestamp
    );
    //Out Item owner change
    ItemTransferOffchainTable.set(
      DEPLOYMENT_NAMESPACE.itemTransferTableId(),
      smartObjectId,
      outItemId,
      inventoryOwner,
      ephItemOwner,
      outItems[0].quantity,
      block.timestamp
    );
  }

  function _inventoryLib() internal view returns (InventoryLib.World memory) {
    if (!ResourceIds.getExists(WorldResourceIdLib.encodeNamespace(DEPLOYMENT_NAMESPACE))) {
      return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });
    } else return InventoryLib.World({ iface: IBaseWorld(_world()), namespace: DEPLOYMENT_NAMESPACE });
  }
}

contract EphemeralInventoryTest is Test {
  using Utils for bytes14;
  using SmartDeployableUtils for bytes14;
  using EntityRecordUtils for bytes14;
  using InventoryLib for InventoryLib.World;
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld baseWorld;
  //   InventoryLib.World ephemeralInventory;
  InventoryLib.World inventory;
  InventoryModule inventoryModule;

  VendingMachineTestSystem private vendingMachineSystem = new VendingMachineTestSystem();
  bytes16 constant SYSTEM_NAME = bytes16("System");
  ResourceId constant VENDING_MACHINE_SYSTEM_ID =
    ResourceId.wrap((bytes32(abi.encodePacked(RESOURCE_SYSTEM, DEPLOYMENT_NAMESPACE, SYSTEM_NAME))));

  function setUp() public {
    baseWorld = IBaseWorld(address(new World()));
    baseWorld.initialize(createCoreModule());
    inventoryModule = new InventoryModule();
    baseWorld.installModule(inventoryModule, abi.encode(DEPLOYMENT_NAMESPACE));
    StoreSwitch.setStoreAddress(address(baseWorld));
    inventory = InventoryLib.World(baseWorld, DEPLOYMENT_NAMESPACE);

    baseWorld.registerSystem(VENDING_MACHINE_SYSTEM_ID, vendingMachineSystem, true);

    // Register system's functions
    baseWorld.registerFunctionSelector(VENDING_MACHINE_SYSTEM_ID, "interactHandler(uint256, address, uint256)");

    //Mock Smart Storage Unit data
    EntityRecordTableData memory entity1 = EntityRecordTableData({ typeId: 1, itemId: 2345, volume: 100 });
    EntityRecordTableData memory entity2 = EntityRecordTableData({ typeId: 45, itemId: 1, volume: 50 });
    EntityRecordTableData memory entity3 = EntityRecordTableData({ typeId: 46, itemId: 2, volume: 70 });

    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
    uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));

    EntityRecordTable.set(
      DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      smartObjectId,
      entity1.itemId,
      entity1.typeId,
      entity1.volume
    );
    EntityRecordTable.set(
      DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      itemObjectId1,
      entity2.itemId,
      entity2.typeId,
      entity2.volume
    );
    EntityRecordTable.set(
      DEPLOYMENT_NAMESPACE.entityRecordTableId(),
      itemObjectId2,
      entity3.itemId,
      entity3.typeId,
      entity3.volume
    );
    uint256 storageCapacity = 5000;
    address inventoryOwner = address(1);
    address ephItemOwner = address(0);

    DeployableState.setState(DEPLOYMENT_NAMESPACE.deployableStateTableId(), smartObjectId, State.ONLINE);
    inventory.setInventoryCapacity(smartObjectId, storageCapacity);
    inventory.setEphemeralInventoryCapacity(smartObjectId, inventoryOwner, storageCapacity);

    InventoryItem[] memory invItems = new InventoryItem[](1);
    invItems[0] = InventoryItem(itemObjectId1, inventoryOwner, entity2.typeId, entity2.itemId, 50, 10);

    InventoryItem[] memory ephInvItems = new InventoryItem[](1);
    ephInvItems[0] = InventoryItem(itemObjectId2, ephItemOwner, entity3.typeId, entity3.itemId, 70, 10);

    inventory.depositToInventory(smartObjectId, invItems);
    inventory.depositToEphemeralInventory(smartObjectId, inventoryOwner, ephInvItems);
  }

  function testSetup() public {
    address EpheremalSystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId());
    ResourceId ephemeralInventorySystemId = SystemRegistry.get(EpheremalSystem);
    assertEq(ephemeralInventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address InventorySystem = Systems.getSystem(DEPLOYMENT_NAMESPACE.inventorySystemId());
    ResourceId inventorySystemId = SystemRegistry.get(InventorySystem);
    assertEq(inventorySystemId.getNamespace(), DEPLOYMENT_NAMESPACE);

    address VendingMachineSystem = Systems.getSystem(VENDING_MACHINE_SYSTEM_ID);
    ResourceId vendingMachineSystemId = SystemRegistry.get(VendingMachineSystem);
    assertEq(vendingMachineSystemId.getNamespace(), DEPLOYMENT_NAMESPACE);
  }

  function testInteractHandler() public {
    IWorld world = IWorld(address(baseWorld));
    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    uint256 itemObjectId1 = uint256(keccak256(abi.encode("item:45")));
    uint256 itemObjectId2 = uint256(keccak256(abi.encode("item:46")));
    address inventoryOwner = address(1);
    address ephItemOwner = address(0);
    uint256 quantity = 2;

    InventoryItemTableData memory inventoryItem = InventoryItemTable.get(
      DEPLOYMENT_NAMESPACE.inventoryItemTableId(),
      smartObjectId,
      itemObjectId1
    );
    assertEq(inventoryItem.quantity, 10);

    EphemeralInvItemTableData memory ephInvItem = EphemeralInvItemTable.get(
      DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      itemObjectId2,
      ephItemOwner
    );
    assertEq(ephInvItem.quantity, 10);

    world.call(
      VENDING_MACHINE_SYSTEM_ID,
      abi.encodeCall(VendingMachineTestSystem.interactHandler, (smartObjectId, inventoryOwner, quantity))
    );

    inventoryItem = InventoryItemTable.get(DEPLOYMENT_NAMESPACE.inventoryItemTableId(), smartObjectId, itemObjectId1);
    assertEq(inventoryItem.quantity, 8);

    ephInvItem = EphemeralInvItemTable.get(
      DEPLOYMENT_NAMESPACE.ephemeralInventoryItemTableId(),
      smartObjectId,
      itemObjectId2,
      ephItemOwner
    );
    assertEq(ephInvItem.quantity, 8);
  }
}
