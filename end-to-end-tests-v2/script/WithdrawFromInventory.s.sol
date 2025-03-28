pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, InventoryItemData, InventoryItem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { InventorySystem, inventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";

import { InventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract WithdrawFromInventory is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    string memory mnemonic = "test test test test test test test test test test test junk";
    address alice = vm.addr(vm.deriveKey(mnemonic, 2));

    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 NON_SINGLETON_ITEM_TYPE_ID = 9090;

    uint256 smartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);
    uint256 nonSingletonObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      quantity: 2 // Withdraw 2 of 9
    });

    world.callFrom(
      alice,
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.withdrawInventory, (smartObjectId, items))
    );

    InventoryItemData memory itemData = InventoryItem.get(smartObjectId, nonSingletonObjectId);
    console.log("Item data:", itemData.quantity); // should be 7

    vm.stopBroadcast();
  }
}
