pragma solidity >=0.8.24;

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
    
    // Test values for creating the smart character
    // TODO accept as parameters to the run method for test reproducability
    uint256 characterId = 1253;
      // The address this character will be minted to
    address characterAddress = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    uint8 typeId = uint8(123);
    uint256 itemId = 234;
    uint256 volume = 100;
    string memory cid = "azerty";
    string memory characterName = "awesome-o";

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
