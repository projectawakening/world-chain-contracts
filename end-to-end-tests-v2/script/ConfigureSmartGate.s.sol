pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { SmartGateSystem, smartGateSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract ConfigureSmartGate is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    IWorldWithContext world = IWorldWithContext(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.addr(deployerPrivateKey);
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);

    // Mock builder deployment of custom canJumpsystem
    bytes14 namespace = bytes14("spaceforalice");
    bytes16 name = bytes16("SmartGateTestSys");
    // Create resource ID for the mock system using the proper format
    ResourceId customSystemId = WorldResourceIdLib.encode(RESOURCE_SYSTEM, namespace, name);

    vm.startBroadcast(alicePrivateKey);
    world.registerNamespace(WorldResourceIdLib.encodeNamespace(namespace));
    SmartGateTestSystem customSystem = new SmartGateTestSystem();
    world.registerSystem(customSystemId, customSystem, true);

    bytes32 tenantId = Tenant.get();
    uint256 characterId = CharactersByAccount.getSmartObjectId(alice);
    uint256 smartGate1ItemId = 1557;
    uint256 smartGate2ItemId = 1558;
    uint256 smartGate1SmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, smartGate1ItemId);
    uint256 smartGate2SmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, smartGate2ItemId);

    // Bring the smart gate online
    deployableSystem.bringOnline(smartGate1SmartObjectId);
    deployableSystem.bringOnline(smartGate2SmartObjectId);

    smartGateSystem.configureGate(smartGate1SmartObjectId, customSystemId);
    world.registerDelegation(admin, UNLIMITED_DELEGATION, new bytes(0));
    vm.stopBroadcast();

    vm.startBroadcast(deployerPrivateKey);
    world.callFrom(
      alice,
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.linkGates, (smartGate1SmartObjectId, smartGate2SmartObjectId))
    );

    world.callFrom(
      alice,
      smartGateSystem.toResourceId(),
      abi.encodeCall(SmartGateSystem.canJump, (characterId, smartGate1SmartObjectId, smartGate2SmartObjectId))
    );
    bool possibleToJump = smartGateSystem.canJump(characterId, smartGate1SmartObjectId, smartGate2SmartObjectId);
    console.log("possibleToJump", possibleToJump); // should be false

    vm.stopBroadcast();
  }
}

//Mock Contract for testing
contract SmartGateTestSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return true;
  }
}
