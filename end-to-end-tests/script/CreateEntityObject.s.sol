pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@eveworld/world/src/codegen/world/IWorld.sol";
import { EntityRecordLib } from "@eveworld/world/src/modules/entity-record/EntityRecordLib.sol";
import { ModulesInitializationLibrary } from "@eveworld/world/src/utils/ModulesInitializationLibrary.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

contract CreateEntityObject is Script {
  using EntityRecordLib for EntityRecordLib.World;

  function run(address worldAddress, uint256 entityId, uint256 itemId, uint256 typeId, uint256 volume) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    EntityRecordLib.World memory entityRecord = EntityRecordLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    ModulesInitializationLibrary.createAndAssociateEntityRecord(IBaseWorld(worldAddress), entityId);

    entityRecord.createEntityRecord(entityId, itemId, typeId, volume);

    vm.stopBroadcast();
  }
}
