pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { EntityRecordData, SmartObjectData, WorldPosition, Coord } from "@eveworld/world/src/modules/smart-storage-unit/types.sol";
import { GateKeeperLib } from "@eveworld/world/src/modules/gate-keeper/GateKeeperLib.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

contract GateKeeperConfig is Script {
  using GateKeeperLib for GateKeeperLib.World;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    GateKeeperLib.World memory gateKeeper = GateKeeperLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2346")));

    gateKeeper.setAcceptedItemTypeId(smartObjectId, 23);
    gateKeeper.setTargetQuantity(smartObjectId, 1000);

    vm.stopBroadcast();
  }
}
