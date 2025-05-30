pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, EphemeralInvItemData, EphemeralInvItem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract WithdrawFromEphemeral is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    address bob = vm.addr(vm.deriveKey(mnemonic, 3));

    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    bytes32 tenantId = Tenant.get();
    uint256 ssuSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, 1244);

    uint256 nonSingletonObjectId = ObjectIdLib.calculateObjectId(tenantId, 9090);

    InventoryItemParams[] memory items = new InventoryItemParams[](1);
    items[0] = InventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      quantity: 5 // Withdraw 5 of 13
    });

    // withdrawEphemeral is a validated call, validated calls must be made from the deployer account via delegation using world.callFrom
    world.callFrom(
      bob,
      ephemeralInventorySystem.toResourceId(),
      abi.encodeCall(EphemeralInventorySystem.withdrawEphemeral, (ssuSmartObjectId, bob, items))
    );

    EphemeralInvItemData memory itemData = EphemeralInvItem.get(ssuSmartObjectId, bob, nonSingletonObjectId);
    console.log("Expected 8, Item quantity:", itemData.quantity); // should be 8

    vm.stopBroadcast();
  }
}
