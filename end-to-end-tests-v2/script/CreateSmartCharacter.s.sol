pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { EntityRecordData, EntityMetadata } from "@eveworld/world-v2/src/systems/entity-record/types.sol";
import { SmartCharacterSystem } from "@eveworld/world-v2/src/systems/smart-character/SmartCharacterSystem.sol";
import { SmartCharacterUtils } from "@eveworld/world-v2/src/systems/smart-character/SmartCharacterUtils.sol";

contract CreateSmartCharacter is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);

    // Test values for creating the smart character
    uint256 characterId = 123;
    address characterAddress = vm.addr(deployerPrivateKey);
    uint256 tribeId = 100;
    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    ResourceId systemId = SmartCharacterUtils.smartCharacterSystemId();
    world.call(
      systemId,
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterId, characterAddress, tribeId, entityRecord, entityRecordMetadata)
      )
    );

    vm.stopBroadcast();
  }
}
