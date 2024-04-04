pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { SmartObjectData } from "../src/modules/types.sol";
import { EntityRecordTableData } from "../src/codegen/tables/EntityRecordTable.sol";


contract CreateSmartCharacter is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    uint256 characterId = vm.envUint("CHARACTER_ID");
    address characterAddress = vm.envAddress("CHARATER_ADDRESS");
    uint8 typeId = uint8(vm.envUint("CHARACTER_TYPE_ID"));
    uint256 itemId = vm.envUint("CHARACTER_ITEM_ID");
    uint256 volume = vm.envUint("CHARACTER_VOLUME");
    string memory cid = vm.envString("CHARACTER_TOKEN_CID");
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    IWorld(worldAddress).frontier__createCharacter(
      characterId,
      characterAddress,
      EntityRecordTableData({ typeId: typeId, itemId: itemId, volume: volume }),
      cid
    );
    vm.stopBroadcast();
  }
}
