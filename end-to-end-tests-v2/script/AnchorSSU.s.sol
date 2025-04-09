pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { Tenant, GlobalDeployableState, LocationData } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { SmartStorageUnitSystem, smartStorageUnitSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";

import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract AnchorSSU is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    address alice = vm.addr(vm.deriveKey(mnemonic, 2));

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);

    // check global state and resume if needed
    if (GlobalDeployableState.getIsPaused() == false) {
      deployableSystem.globalResume();
    }

    bytes32 tenantId = Tenant.get();
    uint256 ssuTypeId = vm.envUint("SSU_TYPE_ID");
    uint256 ssuItemId = 1244;
    uint256 fuelUnitVolume = 10;
    uint256 fuelConsumptionIntervalInSeconds = 60;
    uint256 fuelMaxCapacity = 100000000;
    uint256 storageCapacity = 100000000;
    uint256 ephemeralCapacity = 100000000;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);
    LocationData memory locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: ssuTypeId,
      itemId: ssuItemId,
      volume: 1000
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: ssuSmartObjectId,
      assemblyType: "SSU",
      entityRecordParams: entityRecordParams,
      owner: alice,
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity,
      locationData: locationParams
    });

    // createAndAnchorStorageUnit is a validated call, validated calls must be made from the deployer account via delegation using world.callFrom
    world.callFrom(
      alice,
      smartStorageUnitSystem.toResourceId(),
      abi.encodeCall(
        SmartStorageUnitSystem.createAndAnchorStorageUnit,
        (deployableParams, storageCapacity, ephemeralCapacity)
      )
    );

    vm.stopBroadcast();
  }
}
