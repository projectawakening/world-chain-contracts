pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { FuelSystem, fuelSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract DepositFuel is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    IWorldWithContext world = IWorldWithContext(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 ssuItemId = 1244;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);
    // deposit fuel currently can be made directly by ADMIN or by owner of the SSU (via validated call)
    // by ADMIN
    fuelSystem.depositFuel(ssuSmartObjectId, 500);

    // by owner of the SSU (validated call)
    world.callFrom(alice, fuelSystem.toResourceId(), abi.encodeCall(FuelSystem.depositFuel, (ssuSmartObjectId, 500)));

    vm.stopBroadcast();
  }
}
