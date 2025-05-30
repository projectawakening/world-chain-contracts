pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { Tenant, LocationData, DeployableState } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

import { SmartCharacterSystem, smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";
import { SmartTurretSystem, smartTurretSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { NetworkNodeSystem, networkNodeSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/NetworkNodeSystemLib.sol";
import { FuelSystem, fuelSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/FuelSystemLib.sol";

import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { FuelParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/fuel/types.sol";

contract NetworkNodeTestData is Script {
  // Global variables for item IDs
  //Note: Change this when you run the script second time
  uint256 constant CHARACTER_BASE_ITEM_ID = 2000;
  uint256 constant SSU_BASE_ITEM_ID = 2100;
  uint256 constant TURRET_BASE_ITEM_ID = 2200;
  uint256 constant GATE_BASE_ITEM_ID = 2300;
  uint256 constant SINGLETON_ITEM_TYPE_ID = 2400;
  uint256 constant NON_SINGLETON_ITEM_TYPE_ID = 2500;
  uint256 constant SINGLETON_ITEM_BASE_ID = 2600;
  uint256 constant ITEM_VOLUME = 10;
  uint256 constant NETWORK_NODE_ID = 12;
  uint256 constant PRINTER_ITEM_ID = 2700;
  uint256 constant PORTABLE_REFINERY_ITEM_ID = 2800;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env and not .env.local)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);

    // Step 1: Deployer creates characters
    // Note: Remove this when you run the script second time
    vm.startBroadcast(deployerPrivateKey);
    createCharacter(alice);

    // Step 2: Deployer creates Network Node
    bytes32 tenantId = Tenant.get();
    uint256 networkNodeId = ObjectIdLib.calculateObjectId(tenantId, NETWORK_NODE_ID);
    console.log("networkNodeId", networkNodeId);
    createNetworkNode(alice, networkNodeId);

    // Step 3: Deployer creates SSUs for each character
    createSSU(alice, networkNodeId);

    // Step 4: Deployer creates Smart Turrets for each character
    createSmartTurret(alice, networkNodeId);

    // Step 5: Deployer creates other assemblies
    //TODO: Uncomment this when the functionality is working
    createPrinter(alice, networkNodeId);
    createPortableRefinery(alice, networkNodeId);
    vm.stopBroadcast();

    // Step 6: Each character brings their own deployables online
    vm.startBroadcast(alicePrivateKey);
    uint256[] memory assemblyTypeIds = new uint256[](1);
    assemblyTypeIds[0] = NETWORK_NODE_ID;

    uint256 fuelTypeId = vm.envUint("FUEL_TYPE_ID");
    uint256 fuelSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, fuelTypeId);
    fuelSystem.depositFuel(networkNodeId, fuelSmartObjectId, 10);

    bringOnline(assemblyTypeIds);
    vm.stopBroadcast();
  }

  function createCharacter(address account) internal {
    bytes32 tenantId = Tenant.get();
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    uint256 characterItemId = CHARACTER_BASE_ITEM_ID;
    uint256 characterSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, characterItemId);

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: characterTypeId,
      itemId: characterItemId,
      volume: 0
    });

    EntityMetadataParams memory entityRecordMetadataParams = EntityMetadataParams({
      name: "Character",
      dappURL: "xxx",
      description: "Test character"
    });

    uint256 tribeId = 100; // Distribute across 3 tribes

    smartCharacterSystem.createCharacter(
      characterSmartObjectId,
      account,
      tribeId,
      entityRecordParams,
      entityRecordMetadataParams
    );

    console.log("Created character for account:", account);
  }

  function createNetworkNode(address account, uint256 networkNodeSmartObjectId) internal {
    bytes32 tenantId = Tenant.get();
    uint256 networkNodeTypeId = vm.envUint("NETWORK_NODE_TYPE_ID");

    LocationData memory locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: networkNodeTypeId,
      itemId: NETWORK_NODE_ID,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: networkNodeSmartObjectId,
      assemblyType: "NWN",
      entityRecordParams: entityRecordParams,
      owner: account,
      locationData: locationParams
    });

    FuelParams memory fuelParams = FuelParams({
      fuelMaxCapacity: 10000,
      fuelBurnRateInSeconds: 3600 // 1 hour
    });

    networkNodeSystem.createAndAnchorNetworkNode(
      deployableParams,
      fuelParams,
      80, // maxEnergyCapacity
      80 // currentProduction
    );

    console.log("Created Network Node for account:", account);
  }

  function createSSU(address account, uint256 networkNodeId) internal {
    bytes32 tenantId = Tenant.get();
    uint256 ssuTypeId = vm.envUint("SSU_TYPE_ID");
    uint256 storageCapacity = 100000000;
    uint256 ephemeralCapacity = 100000000;

    uint256 ssuItemId = SSU_BASE_ITEM_ID;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, ssuItemId);

    LocationData memory locationParams = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: ssuTypeId,
      itemId: ssuItemId,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: ssuSmartObjectId,
      assemblyType: "SSU",
      entityRecordParams: entityRecordParams,
      owner: account,
      locationData: locationParams
    });

    smartStorageUnitSystem.createAndAnchorStorageUnit(
      deployableParams,
      storageCapacity,
      ephemeralCapacity,
      networkNodeId
    );

    console.log("Created SSU for account:", account);
  }

  function createSmartTurret(address account, uint256 networkNodeId) internal {
    bytes32 tenantId = Tenant.get();
    uint256 smartTurretTypeId = vm.envUint("TURRET_TYPE_ID");

    uint256 turretItemId = TURRET_BASE_ITEM_ID;
    uint256 turretSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, turretItemId);
    LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartTurretTypeId,
      itemId: turretItemId,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: turretSmartObjectId,
      assemblyType: "ST",
      entityRecordParams: entityRecordParams,
      owner: account,
      locationData: locationData
    });

    smartTurretSystem.createAndAnchorTurret(deployableParams, networkNodeId);

    console.log("Created Smart Turret for account:", account);
  }

  function createPrinter(address account, uint256 networkNodeId) internal {
    bytes32 tenantId = Tenant.get();
    uint256 printerTypeId = vm.envUint("PRINTER_TYPE_ID");
    uint256 printerSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, PRINTER_ITEM_ID);

    LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: printerTypeId,
      itemId: PRINTER_ITEM_ID,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: printerSmartObjectId,
      assemblyType: "PR",
      entityRecordParams: entityRecordParams,
      owner: account,
      locationData: locationData
    });

    deployableSystem.createAndAnchor(deployableParams, networkNodeId);
  }

  function createPortableRefinery(address account, uint256 networkNodeId) internal {
    bytes32 tenantId = Tenant.get();
    uint256 portableRefineryTypeId = vm.envUint("PORTABLE_REFINERY_TYPE_ID");
    uint256 portableRefinerySmartObjectId = ObjectIdLib.calculateObjectId(tenantId, PORTABLE_REFINERY_ITEM_ID);

    LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: portableRefineryTypeId,
      itemId: PORTABLE_REFINERY_ITEM_ID,
      volume: 10
    });

    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: portableRefinerySmartObjectId,
      assemblyType: "PRF",
      entityRecordParams: entityRecordParams,
      owner: account,
      locationData: locationData
    });

    deployableSystem.createAndAnchor(deployableParams, networkNodeId);
  }

  function bringOnline(uint256[] memory assemblyItemIds) internal {
    bytes32 tenantId = Tenant.get();
    for (uint256 i = 0; i < assemblyItemIds.length; i++) {
      uint256 assemblyItemId = assemblyItemIds[i];
      uint256 assemblySmartObjectId = ObjectIdLib.calculateObjectId(tenantId, assemblyItemId);
      deployableSystem.bringOnline(assemblySmartObjectId);
    }
  }
}
