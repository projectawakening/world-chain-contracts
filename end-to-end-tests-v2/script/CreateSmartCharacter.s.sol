pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { Tenant, EntityRecordMetadata, EntityRecordMetadataData, Characters, CharactersData, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { SmartCharacterSystem, smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract CreateSmartCharacter is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    address alice = vm.addr(vm.deriveKey(mnemonic, 2));

    vm.startBroadcast(deployerPrivateKey);
    // Test values for creating the smart character
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");
    uint256 characterItemId = 1348;
    bytes32 tenantId = Tenant.get();
    uint256 characterSmartObjectId = ObjectIdLib.calculateSingletonId( tenantId, characterItemId);
    address characterAddress = alice;
    uint256 tribeId = 100;
    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: characterTypeId,
      itemId: characterItemId,
      volume: 0
    });
    EntityMetadataParams memory entityRecordMetadataParams = EntityMetadataParams({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    smartCharacterSystem.createCharacter(characterSmartObjectId, characterAddress, tribeId, entityRecordParams, entityRecordMetadataParams);

    CharactersData memory character = Characters.get(characterSmartObjectId);
    console.log("Character created:");

    console.log("Characters by account:", CharactersByAccount.getSmartObjectId(characterAddress));

    vm.stopBroadcast();
  }
}
