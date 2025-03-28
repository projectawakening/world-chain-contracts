pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { Tenant, LocationData } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { SmartGateSystem, smartGateSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { FuelSystem, fuelSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract AnchorSmartGate is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    address alice = vm.addr(vm.deriveKey(mnemonic, 2));

    vm.startBroadcast(deployerPrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 smartGateTypeId = vm.envUint("GATE_TYPE_ID");
    uint256 smartGate1ItemId = 1557;
    uint256 smartGate2ItemId = 1558;
    uint256 fuelUnitVolume = 10;
    uint256 fuelConsumptionIntervalInSeconds = 60;
    uint256 fuelMaxCapacity = 100000000;

    uint256 smartGate1SmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, smartGate1ItemId);
    uint256 smartGate2SmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, smartGate2ItemId);

    LocationData memory sourceGateLocation = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });
    LocationData memory destinationGateLocation = LocationData({ solarSystemId: 1, x: 1002, y: 1002, z: 1002 });

    EntityRecordParams memory sourceGateEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartGateTypeId,
      itemId: smartGate1ItemId,
      volume: 10
    });

    EntityRecordParams memory destinationGateEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartGateTypeId,
      itemId: smartGate2ItemId,
      volume: 10
    });

    CreateAndAnchorParams memory sourceGateDeployableParams = CreateAndAnchorParams({
      smartObjectId: smartGate1SmartObjectId,
      assemblyType: "SG",
      entityRecordParams: sourceGateEntityRecordParams,
      owner: alice,
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity,
      locationData: sourceGateLocation
    });

    CreateAndAnchorParams memory destinationGateDeployableParams = CreateAndAnchorParams({
      smartObjectId: smartGate2SmartObjectId,
      assemblyType: "SG",
      entityRecordParams: destinationGateEntityRecordParams,
      owner: alice,
      fuelUnitVolume: fuelUnitVolume,
      fuelConsumptionIntervalInSeconds: fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity: fuelMaxCapacity,
      locationData: destinationGateLocation
    });

    smartGateSystem.createAndAnchorGate(sourceGateDeployableParams, 100000000);
    smartGateSystem.createAndAnchorGate(destinationGateDeployableParams, 100000000);

    fuelSystem.depositFuel(smartGate1SmartObjectId, 10000);
    fuelSystem.depositFuel(smartGate2SmartObjectId, 10000);

    vm.stopBroadcast();
  }
}
