pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

import { Tenant, EntityRecordMetadata, EntityRecordMetadataData, Characters, CharactersData, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { SmartCharacterSystem, smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract CreateSmartCharacter is Script {
  function run(address worldAddress) public {
    uint256 aliceCharacterItemId = 1348;
    uint256 bobCharacterItemId = 1349;
    uint256 charlieCharacterItemId = 1350;
    uint256 tribeId = 100;

    StoreSwitch.setStoreAddress(worldAddress);
    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);
    uint256 bobPrivateKey = vm.deriveKey(mnemonic, 3);
    address bob = vm.addr(bobPrivateKey);
    uint256 charliePrivateKey = vm.deriveKey(mnemonic, 4);
    address charlie = vm.addr(charliePrivateKey);

    // this is the first script to be run in end to end tests
    // to mimic the current meta txn transaction flow
    // - create a delegation for the deployer from the alice, bob, and charlie accounts
    // - all "validated" world calls must be made from the deployer account via delegation using world.callFrom
    // - OR direct operational calls can be made from the deployer account using world.call (via system library calls)
    // - OR calls can be made directly by user accounts where allowed by the configured access control

    vm.startBroadcast(alicePrivateKey);
    world.registerDelegation(vm.addr(deployerPrivateKey), UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();
    vm.startBroadcast(bobPrivateKey);
    world.registerDelegation(vm.addr(deployerPrivateKey), UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();
    vm.startBroadcast(charliePrivateKey);
    world.registerDelegation(vm.addr(deployerPrivateKey), UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();

    vm.startBroadcast(deployerPrivateKey);
    createCharacter(world, alice, aliceCharacterItemId, tribeId);
    createCharacter(world, bob, bobCharacterItemId, tribeId);
    createCharacter(world, charlie, charlieCharacterItemId, tribeId);
    vm.stopBroadcast();
  }

  function createCharacter(
    IWorldWithContext world,
    address characterAddress,
    uint256 characterItemId,
    uint256 tribeId
  ) public {
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    bytes32 tenantId = Tenant.get();
    uint256 characterSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, characterItemId);

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

    // createCharacter is a validated call, validated calls must be made from the deployer account via delegation using world.callFrom
    world.callFrom(
      characterAddress,
      smartCharacterSystem.toResourceId(),
      abi.encodeCall(
        SmartCharacterSystem.createCharacter,
        (characterSmartObjectId, characterAddress, tribeId, entityRecordParams, entityRecordMetadataParams)
      )
    );

    uint256 characterId = CharactersByAccount.getSmartObjectId(characterAddress);
    console.log("Character created:", characterId);
  }
}
