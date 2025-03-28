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
    address bob = vm.addr(vm.deriveKey(mnemonic, 3));
    address charlie = vm.addr(vm.deriveKey(mnemonic, 4));

    vm.startBroadcast(deployerPrivateKey);
    createCharacter(alice, 1348, 100);
    createCharacter(bob, 1349, 100);
    createCharacter(charlie, 1350, 300);
    vm.stopBroadcast();
  }

  function createCharacter(address characterAddress, uint256 characterItemId, uint256 tribeId) public {
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    bytes32 tenantId = Tenant.get();
    uint256 characterSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, characterItemId);

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: characterTypeId,
      itemId: characterItemId,
      volume: 0
    });
    EntityMetadataParams memory entityRecordMetadataParams = EntityMetadataParams({
      name: "xxx",
      dappURL: "xxx",
      description: "xxx"
    });

    smartCharacterSystem.createCharacter(
      characterSmartObjectId,
      characterAddress,
      tribeId,
      entityRecordParams,
      entityRecordMetadataParams
    );

    uint256 characterId = CharactersByAccount.getSmartObjectId(characterAddress);
    console.log("Character created:", characterId);
  }
}
