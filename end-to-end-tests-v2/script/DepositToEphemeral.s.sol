pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

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

    //delegate call from ephemeralInvOwner to admin
    vm.startBroadcast(bobPrivateKey);
    world.registerDelegation(deployer, UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 smartObjectId = ObjectIdLib.calculateSingletonId(tenantId, 1244);

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](2);

    uint256 SINGLETON_ITEM_ID = 88;
    uint256 NON_SINGLETON_ITEM_TYPE_ID = 8080;
    uint256 ITEM_VOLUME = 1;

    uint256 singletonObjectId = ObjectIdLib.calculateSingletonId(tenantId, SINGLETON_ITEM_ID);
    uint256 nonSingletonObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    items[0] = CreateInventoryItemParams({
      smartObjectId: singletonObjectId,
      tenantId: tenantId,
      typeId: 8000,
      itemId: SINGLETON_ITEM_ID,
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

    world.callFrom(
      bob,
      ephemeralInventorySystem.toResourceId(),
      abi.encodeCall(EphemeralInventorySystem.createAndDepositEphemeral, (smartObjectId, bob, items))
    );

    vm.stopBroadcast();
  }
}
