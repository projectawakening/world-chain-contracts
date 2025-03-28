pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { System } from "@latticexyz/world/src/System.sol";


contract ConfigureSmartGate is Script {
  using WorldResourceIdInstance for ResourceId;

  IBaseWorld world;
  address player;

  function run(address worldAddress) public {
  //   StoreSwitch.setStoreAddress(worldAddress);
  //   // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
  //   uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  //   player = vm.addr(deployerPrivateKey);

  //   // Start broadcasting transactions from the deployer account
  //   vm.startBroadcast(deployerPrivateKey);

  //   uint256 sourceGateId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-5550")));
  //   uint256 destinationGateId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-5551")));

  //   //Deploy the Mock contract and configure the smart gate to use it
  //   world = IBaseWorld(worldAddress);

  //   //Create, anchor the smart gate and bring online
  //   anchorFuelAndOnline(sourceGateId);
  //   anchorFuelAndOnline(destinationGateId);
  //   SmartGateTestSystem smartGateTestSystem = new SmartGateTestSystem();
  //   ResourceId smartGateTestSystemId = ResourceId.wrap(
  //     (bytes32(abi.encodePacked(RESOURCE_SYSTEM, "test1ns", "SmartGateTestSys")))
  //   );

  //   //register the smart gate system
  //   world.registerNamespace(smartGateTestSystemId.getNamespaceId());
  //   world.registerSystem(smartGateTestSystemId, smartGateTestSystem, true);
  //   //register the function selector
  //   world.registerFunctionSelector(smartGateTestSystemId, "canJump(uint256, uint256, uint256)");

  //   smartGateSystem.configureSmartGate(sourceGateId, smartGateTestSystemId);
  //   smartGateSystem.linkSmartGates(sourceGateId, destinationGateId);

  //   uint256 characterId = 12513;

  //   bool possibleToJump = smartGateSystem.canJump(characterId, sourceGateId, destinationGateId);
  //   console.logBool(possibleToJump); //false

  //   vm.stopBroadcast();
  // }

  // function anchorFuelAndOnline(uint256 smartObjectId) public {
  //   // check global state and resume if needed
  //   if (GlobalDeployableState.getIsPaused() == false) {
  //     deployableSystem.globalResume();
  //   }
  //   EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });
  //   SmartObjectData memory smartObjectData = SmartObjectData({ owner: player, tokenURI: "test" });
  //   LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

  //   CreateAndAnchorDeployableParams memory params = CreateAndAnchorDeployableParams({
  //     smartObjectId: smartObjectId,
  //     smartAssemblyType: SMART_GATE,
  //     entityRecordData: entityRecord,
  //     smartObjectData: smartObjectData,
  //     fuelUnitVolume: 10,
  //     fuelConsumptionIntervalInSeconds: 3600,
  //     fuelMaxCapacity: 1000000000,
  //     locationData: locationData
  //   });

  //   smartGateSystem.createAndAnchorSmartGate(params, 100010000 * 1e18);
  //   fuelSystem.depositFuel(smartObjectId, 200010);
  //   deployableSystem.bringOnline(smartObjectId);
  }
}

//Mock Contract for testing
contract SmartGateTestSystem is System {
  function canJump(uint256 characterId, uint256 sourceGateId, uint256 destinationGateId) public view returns (bool) {
    return false;
  }
}
