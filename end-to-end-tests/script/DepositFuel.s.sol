pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@eve/frontier-world/src/codegen/world/IWorld.sol";
import { InventoryItem } from "@eve/frontier-world/src/modules/smart-storage-unit/types.sol";
import { SmartDeployableLib } from "@eve/frontier-world/src/modules/smart-deployable/SmartDeployableLib.sol";

contract DepositFuel is Script {
  using SmartDeployableLib for SmartDeployableLib.World;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    SmartDeployableLib.World memory smartDeployable = SmartDeployableLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: "frontier"
    });

    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));

    smartDeployable.depositFuel(smartObjectId, 1000);

    vm.stopBroadcast();
  }
}
