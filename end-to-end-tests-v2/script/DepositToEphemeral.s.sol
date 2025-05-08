pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, EphemeralInvItemData, EphemeralInvItem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { EphemeralInventorySystem, ephemeralInventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { CreateInventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract DepositToEphemeral is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 bobPrivateKey = vm.deriveKey(mnemonic, 3);
    address bob = vm.addr(bobPrivateKey);

    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    uint256 SINGLETON_ITEM_TYPE_ID = 9000; // same singeton type as in DepositToInventory.s.sol
    // previous singleton is already owned by alice's ssu inventory, so we must use a new singleton item id
    uint256 NEW_SINGLETON_ITEM_ID = 77; // new singleton item id
    uint256 NON_SINGLETON_ITEM_TYPE_ID = 9090; // same non-singleton type as in DepositToInventory.s.sol
    uint256 ITEM_VOLUME = 10; // same item volume as in DepositToInventory.s.sol

    uint256 newSingletonObjectId = ObjectIdLib.calculateSingletonId(tenantId, NEW_SINGLETON_ITEM_ID);
    uint256 nonSingletonObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    items[0] = CreateInventoryItemParams({
      smartObjectId: newSingletonObjectId,
      tenantId: tenantId,
      typeId: SINGLETON_ITEM_TYPE_ID,
      itemId: NEW_SINGLETON_ITEM_ID,
      quantity: 1,
      volume: ITEM_VOLUME
    });

    // Second item: non-singleton item
    items[1] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0,
      quantity: 13,
      volume: ITEM_VOLUME
    });

    // createAndDepositEphemeral is a validated call, validated calls must be made from the deployer account via delegation using world.callFrom
    world.callFrom(
      bob,
      ephemeralInventorySystem.toResourceId(),
      abi.encodeCall(EphemeralInventorySystem.createAndDepositEphemeral, (ssuSmartObjectId, bob, items))
    );

    EphemeralInvItemData memory itemData = EphemeralInvItem.get(ssuSmartObjectId, bob, newSingletonObjectId);
    console.log("Expected 1, Singleton item quantity:", itemData.quantity); // should be 1

    EphemeralInvItemData memory itemData2 = EphemeralInvItem.get(ssuSmartObjectId, bob, nonSingletonObjectId);
    console.log("Expected 13, Non-singleton item quantity:", itemData2.quantity); // should be 13

    vm.stopBroadcast();
  }
}
