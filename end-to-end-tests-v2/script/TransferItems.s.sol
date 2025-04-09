pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

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
import { InventoryItemParams, CreateInventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";

import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract TransferItems is Script {
  bytes32 tenantId;
  uint256 aliceSSUItemId;
  uint256 aliceSSUInventoryId;
  uint256 bobSSUItemId;
  uint256 bobSSUInventoryId;
  uint256 charlieSSUItemId;
  uint256 charlieSSUInventoryId;
  uint256 singletonItem1ObjectId; // existing singleton item
  uint256 singletonItem2ObjectId; // existing singleton item
  uint256 singletonItem3ObjectId; // new singleton item
  uint256 nonSingletonItem1ObjectId; // existing non-singleton item

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
    uint256 NEW_SINGLETON_ITEM_ID = 88; // new singleton item id (to put into Charlie's inventory)
    uint256 SINGLETON_ITEM_TYPE_ID = 9000; // same singeton type as in DepositToInventory.s.sol
    uint256 ITEM_VOLUME = 10; // same volume as in DepositToInventory.s.sol

    tenantId = Tenant.get();

    aliceSSUItemId = 1244; // number used in the AnchorSSU.s.sol script
    bobSSUItemId = 6666;
    charlieSSUItemId = 7777;

    aliceSSUInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), aliceSSUItemId);
    bobSSUInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), bobSSUItemId);
    charlieSSUInventoryId = ObjectIdLib.calculateSingletonId(Tenant.get(), charlieSSUItemId);

    singletonItem1ObjectId = ObjectIdLib.calculateSingletonId(tenantId, 66); // from the DepositToInventory.s.sol script (in alice's inventory for alice's SSU)
    singletonItem2ObjectId = ObjectIdLib.calculateSingletonId(tenantId, 77); // from the DepositToEphemeral.s.sol script (in bob's ephemeral inventory for alice's SSU)
    singletonItem3ObjectId = ObjectIdLib.calculateSingletonId(tenantId, NEW_SINGLETON_ITEM_ID); // new singleton item id (to put into Charlie's inventory)
    nonSingletonItem1ObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, 9090); // from the DepositToInventory/DepositToEphemeral.s.sol script (7 in alice's inventory for alice's SSU, 8 in bob's ephemeral inventory for alice's SSU)

    // create an SSU with primary inventory for bob and charlie
    vm.startBroadcast(deployerPrivateKey);

    // alice SSU already created in the AnchorSSU.s.sol script

    // create an SSU with primary inventory for bob
    createInventory(world, bobSSUInventoryId, bob, bobSSUItemId);
    vm.stopBroadcast();

    // initial inventory items for Alice:
    // - 1 singleton item of precious metal (singletonItem1ObjectId)
    // - 7 non-singleton items of ore (nonSingletonItem1ObjectId)

    // initial ephemeral inventory items for Bob:
    // - 1 singleton item of precious metal (singletonItem2ObjectId)
    // - 8 non-singleton items of ore (nonSingletonItem1ObjectId)

    // Alice shares her singleton precious metal with Bob's SSU inventory directly
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: singletonItem1ObjectId, quantity: 1 });

    // Transfer From Inventory to Inventory : Alice Inventory to Bob Inventory
    vm.startBroadcast(alicePrivateKey);
    inventoryInteractSystem.transferToInventory(aliceSSUInventoryId, bobSSUInventoryId, transferItems);
    vm.stopBroadcast();

    // Now as a act of goodwill, Bob transfers 50% of his ore to Charlie's Ephemeral Inventory attached to Alice's SSU
    InventoryItemParams[] memory ephemeralTransferItems = new InventoryItemParams[](1);
    ephemeralTransferItems[0] = InventoryItemParams({ smartObjectId: nonSingletonItem1ObjectId, quantity: 4 });

    // Transfer From Ephemeral to Ephemeral : Bob's Ephemeral to Charlie's Ephemeral attached to Alice's SSU
    vm.startBroadcast(bobPrivateKey);
    ephemeralInteractSystem.crossTransferToEphemeral(aliceSSUInventoryId, bob, charlie, ephemeralTransferItems);
    vm.stopBroadcast();

    // Charlie shares 50% of his new ore with Alice
    ephemeralTransferItems[0] = InventoryItemParams({ smartObjectId: nonSingletonItem1ObjectId, quantity: 2 });

    // Transfer From Ephemeral to Inventory : Charlie's Ephemeral to Alice's SSU Inventory
    vm.startBroadcast(charliePrivateKey);
    ephemeralInteractSystem.transferFromEphemeral(aliceSSUInventoryId, charlie, ephemeralTransferItems);
    vm.stopBroadcast();

    // Seeing Charlie's generosity, Bob sends his recently recieved precious metal to Charlie's ephemral inventory on Bob's SSU
    // Transfer From Inventory to Ephemeral : Bob's SSU Inventory to Charlie's Ephemeral attached to Bob's SSU
    vm.startBroadcast(bobPrivateKey);
    ephemeralInteractSystem.transferToEphemeral(bobSSUInventoryId, charlie, transferItems);
    vm.stopBroadcast();

    //Exchange/Trade items using an external contract by setting permissions for the external contract
    vm.startBroadcast(alicePrivateKey);
    contractTransfer(world, aliceSSUInventoryId, bobSSUInventoryId);
    vm.stopBroadcast();
  }

  function contractTransfer(IWorldWithContext world, uint256 fromInventoryId, uint256 toInventoryId) public {
    // Mock builder deployment of custom interact system
    // Create resource ID for the mock system using the proper format
    bytes14 namespace = bytes14("aliceinspace");
    bytes16 name = bytes16("AliceCustomInv");
    ResourceId customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    // Deploy and register the custom system
    CustomInventoryInteractSystem customSystem = new CustomInventoryInteractSystem();

    // Register the system with the world
    world.registerSystem(customSystemId, customSystem, true);

    inventoryInteractSystem.setTransferToInventoryAccess(fromInventoryId, address(customSystem), true);

    // ALice will send 5 ore to Bob (she has 9 ore in her inventory)
    InventoryItemParams[] memory transferItems = new InventoryItemParams[](1);
    transferItems[0] = InventoryItemParams({ smartObjectId: nonSingletonItem1ObjectId, quantity: 5 });

    world.call(
      customSystemId,
      abi.encodeWithSelector(
        CustomInventoryInteractSystem.callTransferToInventory.selector,
        fromInventoryId,
        toInventoryId,
        transferItems
      )
    );
    // alice has 4 ore in her inventory, and 1 precious metal in her inventory
    // bob has 5 ore in his inventory, 4 ore in his ephemeral inventory, and 0 precious metal
    // charlie has 2 ore in his ephemeral inventory (on Alice's SSU), and 1 precious metal in his ephemeral inventory (on Bob's SSU)
  }

  function createInventory(
    IWorldWithContext world,
    uint256 ssuSmartObjectId,
    address invOwner,
    uint256 ssuItemId
  ) public {
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

    world.callFrom(
      invOwner,
      smartStorageUnitSystem.toResourceId(),
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorStorageUnit,
        (deployableParams, storageCapacity, ephemeralCapacity)
      )
    );

    world.callFrom(
      invOwner,
      fuelSystem.toResourceId(),
      abi.encodeCall(FuelSystem.depositFuel, (ssuSmartObjectId, 1000))
    );

    world.callFrom(
      invOwner,
      deployableSystem.toResourceId(),
      abi.encodeCall(DeployableSystem.bringOnline, (ssuSmartObjectId))
    );
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
