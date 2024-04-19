pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@eve/frontier-world/src/codegen/world/IWorld.sol";
import { SmartObjectData } from "@eve/frontier-world/src/modules/types.sol";
import { EntityRecordTableData } from "@eve/frontier-world/src/codegen/tables/EntityRecordTable.sol";
import { SmartCharacterLib } from "@eve/frontier-world/src/modules/smart-character/SmartCharacterLib.sol";
import { EntityRecordOffchainTableData } from "@eve/frontier-world/src/codegen/tables/EntityRecordOffchainTable.sol";

contract CreateSmartCharacter is Script {
  using SmartCharacterLib for SmartCharacterLib.World;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    uint256 characterId = vm.envUint("CHARACTER_ID");
    address characterAddress = vm.envAddress("CHARACTER_ADDRESS");
    uint8 typeId = uint8(vm.envUint("CHARACTER_TYPE_ID"));
    uint256 itemId = vm.envUint("CHARACTER_ITEM_ID");
    uint256 volume = vm.envUint("CHARACTER_VOLUME");
    string memory cid = vm.envString("CHARACTER_TOKEN_CID");
    string memory characterName = vm.envString("CHARACTER_NAME");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    SmartCharacterLib.World memory smartCharacter = SmartCharacterLib.World({iface: IBaseWorld(worldAddress), namespace: "frontier" });
    
    smartCharacter.createCharacter(
      characterId,
      characterAddress,
      EntityRecordTableData({ typeId: typeId, itemId: itemId, volume: volume }),
      EntityRecordOffchainTableData({name: characterName, dappURL: "noURL", description: "."}),
      cid
    );
    vm.stopBroadcast();
  }
}
