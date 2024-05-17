pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@eveworld/frontier-world/src/codegen/world/IWorld.sol";
import { InventoryItem } from "@eveworld/frontier-world/src/modules/inventory/types.sol";
import { SmartStorageUnitLib } from "@eveworld/frontier-world/src/modules/smart-storage-unit/SmartStorageUnitLib.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

contract DepositToInventory is Script {
  using SmartStorageUnitLib for SmartStorageUnitLib.World;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address invOwner = vm.addr(deployerPrivateKey);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    SmartStorageUnitLib.World memory smartStorageUnit = SmartStorageUnitLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    InventoryItem[] memory items = new InventoryItem[](1);
    items[0] = InventoryItem({ inventoryItemId: 123, owner: invOwner, itemId: 12, typeId: 3, volume: 10, quantity: 5 });

    smartStorageUnit.createAndDepositItemsToInventory(smartObjectId, items);

    vm.stopBroadcast();
  }
}
