pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";
import { InventorySystem, inventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { CreateInventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";

contract DepositToInventory is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.addr(deployerPrivateKey);

    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);

    IWorldWithContext world = IWorldWithContext(worldAddress);

    //Simulate meta txn signed by player
    vm.startBroadcast(alicePrivateKey);
    //delegate call to admin
    world.registerDelegation(admin, UNLIMITED_DELEGATION, new bytes(0));

    vm.stopBroadcast();

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 smartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    uint256 SINGLETON_ITEM_TYPE_ID = 9000;
    uint256 SINGLETON_ITEM_ID = 66;
    uint256 NON_SINGLETON_ITEM_TYPE_ID = 9090;
    uint256 ITEM_VOLUME = 10;

    uint256 singletonObjectId = ObjectIdLib.calculateSingletonId(tenantId, SINGLETON_ITEM_ID);
    uint256 nonSingletonObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    //add as singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_ITEM_TYPE_ID,
      itemId: SINGLETON_ITEM_ID,
      quantity: 1, // Singleton can only have quantity of 1
      volume: ITEM_VOLUME
    });

    //add as non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0, // For non-singleton items, itemId is zero
      quantity: 9, // Non-singleton can have any quantity
      volume: ITEM_VOLUME
    });

    world.callFrom(
      alice,
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.createAndDepositInventory, (smartObjectId, items))
    );

    vm.stopBroadcast();
  }
}
