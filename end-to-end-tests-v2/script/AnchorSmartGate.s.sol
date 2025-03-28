pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
contract AnchorSmartGate is Script {
  function run(address worldAddress) public {
    // StoreSwitch.setStoreAddress(worldAddress);
    // // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    // address player = vm.addr(deployerPrivateKey);

    // ResourceId smartGateSystemId = smartGateSystem.toResourceId();
    // ResourceId deployableSystemId = deployableSystem.toResourceId();

    // // Start broadcasting transactions from the deployer account
    // vm.startBroadcast(deployerPrivateKey);
    // IBaseWorld world = IBaseWorld(worldAddress);

    // // check global state and resume if needed
    // if (GlobalDeployableState.getIsPaused() == false) {
    //   deployableSystem.globalResume();
    // }

    // uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-00003")));
    // EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });
    // SmartObjectData memory smartObjectData = SmartObjectData({ owner: player, tokenURI: "test" });
    // LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    // CreateAndAnchorDeployableParams memory params = CreateAndAnchorDeployableParams({
    //   smartObjectId: smartObjectId,
    //   smartAssemblyType: SMART_GATE,
    //   entityRecordData: entityRecord,
    //   smartObjectData: smartObjectData,
    //   fuelUnitVolume: 10,
    //   fuelConsumptionIntervalInSeconds: 3600,
    //   fuelMaxCapacity: 1000000000,
    //   locationData: locationData
    // });

    // smartGateSystem.createAndAnchorSmartGate(params, 100010000 * 1e18);

    // vm.stopBroadcast();
  }
}
