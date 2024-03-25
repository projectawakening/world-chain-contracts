pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { EntityRecordData, SmartObjectData } from "../src/modules/types.sol";

contract CreateSmartCharacter is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    IWorld(worldAddress).frontier__createCharacter(
      123,
      0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
      EntityRecordData({ typeId: 123, itemId: 222, volume: 100 }),
      SmartObjectData({ owner: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8, tokenURI: "https://example.com/token/123" })
    );
    vm.stopBroadcast();
  }
}
