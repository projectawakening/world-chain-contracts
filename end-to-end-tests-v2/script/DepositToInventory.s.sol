pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, InventoryItemData, InventoryItem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
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

    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244; // value from AnchorSSU.s.sol
    uint256 ssuSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, ssuItemId);
    uint256 SINGLETON_ITEM_TYPE_ID = 9000;
    uint256 SINGLETON_ITEM_ID = 66;
    uint256 NON_SINGLETON_ITEM_TYPE_ID = 9090;
    uint256 ITEM_VOLUME = 10;
    uint256 singletonObjectId = ObjectIdLib.calculateObjectId(tenantId, SINGLETON_ITEM_ID);
    uint256 nonSingletonObjectId = ObjectIdLib.calculateObjectId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);
    // add a singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_ITEM_TYPE_ID,
      itemId: SINGLETON_ITEM_ID,
      quantity: 1, // Singleton can only have quantity of 1
      volume: ITEM_VOLUME
    });

    //add a non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0, // For non-singleton items, itemId is zero
      quantity: 9, // Non-singleton can have any quantity
      volume: ITEM_VOLUME
    });
    // this is the first time we are putting these items on-chain so we must call createAndDepositInventory
    // createAndDepositInventory is a validated call, validated calls must be made from the deployer account via delegation using world.callFrom
    world.callFrom(
      alice,
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.createAndDepositInventory, (ssuSmartObjectId, items))
    );

    InventoryItemData memory itemData = InventoryItem.get(ssuSmartObjectId, singletonObjectId);
    console.log("Expected 1, Singleton item quantity:", itemData.quantity); // should be 1

    InventoryItemData memory itemData2 = InventoryItem.get(ssuSmartObjectId, nonSingletonObjectId);
    console.log("Expected 9, Non-singleton item quantity:", itemData2.quantity); // should be 9

    vm.stopBroadcast();
  }
}
