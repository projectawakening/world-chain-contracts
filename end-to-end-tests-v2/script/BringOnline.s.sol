pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { Tenant, DeployableState } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract BringOnline is Script {
  // assumes CreateAndAnchor.s.sol and Deposit fuel has been run

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(alicePrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 smartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);

    deployableSystem.bringOnline(smartObjectId); // needs to have some fuel in it to work, else it will just let the state to offline

    console.log("Deployable brought online");
    console.log("Deployable state:", uint8(DeployableState.getCurrentState(smartObjectId)));
    vm.stopBroadcast();
  }
}
