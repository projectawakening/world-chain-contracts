pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, InventoryItemData, InventoryItem, LocationData, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { FuelSystem, fuelSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";
import { InventorySystem, inventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystem, inventoryInteractSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventoryInteractSystemLib.sol";
import { EphemeralInteractSystem, ephemeralInteractSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInteractSystemLib.sol";
import { InventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";

import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract TransferItems is Script {
  bytes32 tenantId;
  uint256 aliceInventoryId;
  uint256 bobInventoryId;
  uint256 charlieInventoryId;
  uint256 item1ObjectId;
  uint256 item2ObjectId;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);
    uint256 bobPrivateKey = vm.deriveKey(mnemonic, 3);
    address bob = vm.addr(bobPrivateKey);
    uint256 charliePrivateKey = vm.deriveKey(mnemonic, 4);
    address charlie = vm.addr(charliePrivateKey);

    IWorldWithContext world = IWorldWithContext(worldAddress);

    vm.startBroadcast(charliePrivateKey);
    world.registerDelegation(vm.addr(deployerPrivateKey), UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();

    tenantId = Tenant.get();
    aliceInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), 5555);
    bobInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), 6666);
    charlieInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), 7777);
    item1ObjectId = ObjectIdLib.calculateSingletonId(tenantId, 66);
    item2ObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, 9090);

    //Inventory Items for alice : Alice has precious metal
    InventoryItemParams[] memory invItems = new InventoryItemParams[](1);
    invItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    //Ephemeral Items for Bob : Bob has a stack of ore
    InventoryItemParams[] memory ephemeralItems = new InventoryItemParams[](1);
    ephemeralItems[0] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 20 });

    // vm.startBroadcast(deployerPrivateKey);
    //Create inventory for alice
    createInventory(aliceInventoryId, alice, 5555);
    world.callFrom(
      alice,
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.depositInventory, (aliceInventoryId, invItems))
    );
    world.callFrom(
      bob,
      ephemeralInventorySystem.toResourceId(),
      abi.encodeCall(EphemeralInventorySystem.depositEphemeral, (aliceInventoryId, bob, ephemeralItems))
    );

    // Create inventory for bob
    createInventory(bobInventoryId, bob, 6666);

    //Create inventory for charlie
    createInventory(charlieInventoryId, charlie, 7777);
    world.callFrom(
      charlie,
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.depositInventory, (charlieInventoryId, invItems))
    );
    vm.stopBroadcast();

    // Alice share
    // Transfer From Inventory to Inventory : Alice Inventory to Bob Inventory
    vm.startBroadcast(alicePrivateKey);
    transferFromInventoryToInventory(aliceInventoryId, bobInventoryId);
    vm.stopBroadcast();

    //Now as a act of goodwill, Bob transfers 50% of his ore to Charlie
    //Transfer From Ephemeral to Ephemeral : Bob's Ephemeral to Charlie's Ephemeral attached to Alice's Inventory
    vm.startBroadcast(bobPrivateKey);
    transferFromEphemeralToEphemeral(aliceInventoryId, bob, charlie);
    vm.stopBroadcast();

    //Charlie shares 50% of his ore with Alice
    //Transfer From Ephemeral to Inventory : Charlie Ephemeral to Alice Inventory
    vm.startBroadcast(charliePrivateKey);
    transferFromEphemeralToInventory(aliceInventoryId, charlie);
    vm.stopBroadcast();

    //Now bob returns his precious metal to end the story
    //Transfer From Inventory to Ephemeral : Bob Inventory to Alice's Ephemeral attached to Bob
    vm.startBroadcast(bobPrivateKey);
    transferFromInventoryToEphemeral(bobInventoryId, alice);
    vm.stopBroadcast();

    //Exchange/Trade items using an external contract by setting permissions for the external contract
    vm.startBroadcast(charliePrivateKey);
    contractTransfer(world, charlieInventoryId, bobInventoryId);
    vm.stopBroadcast();
  }

  function transferFromInventoryToInventory(uint256 fromInventoryId, uint256 toInventoryId) public {
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    //transfer one non singleton item from alice inventory to bob inventory
    inventoryInteractSystem.transferToInventory(fromInventoryId, toInventoryId, transferItems);

    InventoryItemData memory itemData = InventoryItem.get(fromInventoryId, item1ObjectId);
    console.log("Item data:", itemData.quantity); // should be 0

    InventoryItemData memory itemData2 = InventoryItem.get(toInventoryId, item2ObjectId);
    console.log("Item data2:", itemData2.quantity); // should be 5
  }

  function transferFromEphemeralToEphemeral(uint256 ssuSmartObjectId, address from, address to) public {
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 10 });

    ephemeralInteractSystem.crossTransferToEphemeral(ssuSmartObjectId, from, to, transferItems);
  }

  function transferFromEphemeralToInventory(uint256 ssuSmartObjectId, address ephemeralInvOwner) public {
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: item2ObjectId, quantity: 5 });
    ephemeralInteractSystem.transferFromEphemeral(ssuSmartObjectId, ephemeralInvOwner, transferItems);
  }

  function transferFromInventoryToEphemeral(uint256 ssuSmartObjectId, address ephemeralInvOwner) public {
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });
    ephemeralInteractSystem.transferToEphemeral(ssuSmartObjectId, ephemeralInvOwner, transferItems);
  }

  function contractTransfer(IWorldWithContext world, uint256 fromInventoryId, uint256 toInventoryId) public {
    // Mock builder deployment of custom interact system
    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("spaceforalice");
    bytes16 name = bytes16("CustomInventory");
    ResourceId customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Deploy and register the mock system
    CustomInventoryInteractSystem customSystem = new CustomInventoryInteractSystem();

    // Register the system with the world
    world.registerSystem(customSystemId, customSystem, true);

    inventoryInteractSystem.setTransferToInventoryAccess(fromInventoryId, address(customSystem), true);

    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: item1ObjectId, quantity: 1 });

    world.call(
      customSystemId,
      abi.encodeWithSelector(
        CustomInventoryInteractSystem.callTransferToInventory.selector,
        fromInventoryId,
        toInventoryId,
        transferItems
      )
    );

    InventoryItemData memory aliceInventoryItem2 = InventoryItem.get(aliceInventoryId, item2ObjectId);
    console.log("Alice Inventory Item 2 quantity:", aliceInventoryItem2.quantity); // should be 4

    InventoryItemData memory bobInventoryItem2 = InventoryItem.get(bobInventoryId, item2ObjectId);
    console.log("Bob Inventory Item 2 quantity:", bobInventoryItem2.quantity); // should be 5

    vm.stopBroadcast();
  }

  function createInventory(uint256 ssuSmartObjectId, address invOwner, uint256 ssuItemId) public {
    uint256 ssuTypeId = vm.envUint("SSU_TYPE_ID");
    uint256 fuelUnitVolume = 10;
    uint256 fuelConsumptionIntervalInSeconds = 60;
    uint256 fuelMaxCapacity = 100000000;
    uint256 storageCapacity = 100000000;
    uint256 ephemeralCapacity = 100000000;

    LocationData memory locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: ssuTypeId,
      itemId: ssuItemId,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: ssuSmartObjectId,
      assemblyType: "SSU",
      entityRecordParams: entityRecordParams,
      owner: invOwner,
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity,
      locationData: locationParams
    });

    smartStorageUnitSystem.createAndAnchorStorageUnit(deployableParams, storageCapacity, ephemeralCapacity);
    fuelSystem.depositFuel(ssuSmartObjectId, 1000);
    deployableSystem.bringOnline(ssuSmartObjectId);
  }
}

// This fits the expected builder pattern -
//   - create a custom contract that calls into the interact systems, and
//   - then set access config to only allow this custom contract to make calls for thier smart object
contract CustomInventoryInteractSystem is System {
  // Call inventory interact system transferToInventory function
  function callTransferToInventory(
    uint256 inventoryObjectId,
    uint256 toObjectId,
    InventoryItemParams[] memory items
  ) public {
    inventoryInteractSystem.transferToInventory(inventoryObjectId, toObjectId, items);
  }
}
