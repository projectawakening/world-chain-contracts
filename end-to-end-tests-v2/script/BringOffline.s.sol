pragma solidity >=0.8.24;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { Tenant, DeployableState } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract BringOffline is Script {
  // assumes CreateAndAnchor.s.sol and bring online has been run

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);

    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, ssuItemId);

    // SSU is already online from the BringOnline.s.sol script

    // currently bringOffline can be made by ADMIN or by owner of the SSU directly
    vm.startBroadcast(deployerPrivateKey);
    deployableSystem.bringOffline(ssuSmartObjectId);
    console.log("Deployable brought offline by ADMIN");
    console.log("Deployable state should be 2:", uint8(DeployableState.getCurrentState(ssuSmartObjectId)));

    deployableSystem.bringOnline(ssuSmartObjectId); // bring online so owner can bring offline
    vm.stopBroadcast();

    vm.startBroadcast(alicePrivateKey);
    deployableSystem.bringOffline(ssuSmartObjectId);
    console.log("Deployable brought offline by owner");
    console.log("Deployable state should be 2:", uint8(DeployableState.getCurrentState(ssuSmartObjectId)));
    vm.stopBroadcast();
  }
}
