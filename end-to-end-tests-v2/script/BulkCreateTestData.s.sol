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
import { SmartGateSystem, smartGateSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartGateSystemLib.sol";
import { DeployableSystem, deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { InventorySystem, inventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/EphemeralInventorySystemLib.sol";

import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { CreateInventoryItemParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/inventory/types.sol";

contract BulkCreateTestData is Script {
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
  uint256 constant NETWORK_NODE_ID = 0;

  // Helper function to derive private key
  function derivePrivateKey(uint256 index) internal pure returns (uint256) {
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 n = index + 2;
    if (n == 2) return vm.deriveKey(mnemonic, 2);
    if (n == 3) return vm.deriveKey(mnemonic, 3);
    if (n == 4) return vm.deriveKey(mnemonic, 4);
    if (n == 5) return vm.deriveKey(mnemonic, 5);
    if (n == 6) return vm.deriveKey(mnemonic, 6);
    if (n == 7) return vm.deriveKey(mnemonic, 7);
    if (n == 8) return vm.deriveKey(mnemonic, 8);
    if (n == 9) return vm.deriveKey(mnemonic, 9);
    if (n == 10) return vm.deriveKey(mnemonic, 10);
    return vm.deriveKey(mnemonic, 11); // Fallback for any other value
  }

  function run(address worldAddress, uint256 count) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env and not .env.local)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    // Generate multiple accounts for testing
    address[] memory accounts = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      uint256 accountPrivateKey = derivePrivateKey(i);
      accounts[i] = vm.addr(accountPrivateKey);
    }

    // Step 1: Deployer creates characters
    // Note: Remove this when you run the script second time
    vm.startBroadcast(deployerPrivateKey);
    createCharacters(count, accounts);
    vm.stopBroadcast();

    // Step 2: Deployer creates SSUs for each character
    vm.startBroadcast(deployerPrivateKey);
    createSSUs(count, accounts);
    vm.stopBroadcast();

    // Step 3: Deployer creates Smart Turrets for each character
    vm.startBroadcast(deployerPrivateKey);
    createSmartTurrets(count, accounts);
    vm.stopBroadcast();

    // Step 4: Deployer creates Smart Gates (pairs)
    vm.startBroadcast(deployerPrivateKey);
    createSmartGates(count, accounts);
    vm.stopBroadcast();

    // Step 5: Each character brings their own deployables online
    for (uint256 i = 0; i < count; i++) {
      uint256 accountPrivateKey = derivePrivateKey(i);
      vm.startBroadcast(accountPrivateKey);
      bringOnlineForAccount(i, count, accounts);
      vm.stopBroadcast();
    }

    // Step 6: Register delegations from each account to the deployer
    registerDelegations(count, accounts, deployer);

    // Step 7: Deployer deposits to each character's inventory (one account at a time)
    for (uint256 i = 0; i < count; i++) {
      vm.startBroadcast(deployerPrivateKey);
      depositToInventoryForAccount(i, accounts);
      vm.stopBroadcast();
    }
  }

  function createCharacters(uint256 count, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    for (uint256 i = 0; i < count; i++) {
      uint256 characterItemId = CHARACTER_BASE_ITEM_ID + i;
      uint256 characterSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, characterItemId);

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

      uint256 tribeId = 100 + (i % 3); // Distribute across 3 tribes

      smartCharacterSystem.createCharacter(
        characterSmartObjectId,
        accounts[i],
        tribeId,
        entityRecordParams,
        entityRecordMetadataParams
      );

      console.log("Created character for account:", accounts[i]);
    }
  }

  function createSSUs(uint256 count, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    uint256 ssuTypeId = vm.envUint("SSU_TYPE_ID");
    uint256 storageCapacity = 100000000;
    uint256 ephemeralCapacity = 100000000;

    for (uint256 i = 0; i < count; i++) {
      uint256 ssuItemId = SSU_BASE_ITEM_ID + i;
      uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);

      LocationData memory locationParams = LocationData({ solarSystemId: 1, x: 1001 + i, y: 1001 + i, z: 1001 + i });

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
        owner: accounts[i],
        locationData: locationParams
      });

      smartStorageUnitSystem.createAndAnchorStorageUnit(
        deployableParams,
        storageCapacity,
        ephemeralCapacity,
        NETWORK_NODE_ID
      );

      console.log("Created SSU for account:", accounts[i]);
    }
  }

  function createSmartTurrets(uint256 count, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    uint256 smartTurretTypeId = vm.envUint("TURRET_TYPE_ID");

    for (uint256 i = 0; i < count; i++) {
      uint256 turretItemId = TURRET_BASE_ITEM_ID + i;
      uint256 turretSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, turretItemId);

      LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1001 + i, y: 1001 + i, z: 1001 + i });

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
        owner: accounts[i],
        locationData: locationData
      });

      smartTurretSystem.createAndAnchorTurret(deployableParams, NETWORK_NODE_ID);

      console.log("Created Smart Turret for account:", accounts[i]);
    }
  }

  function createSmartGates(uint256 count, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    uint256 smartGateTypeId = vm.envUint("GATE_TYPE_ID");

    // Create pairs of gates (source and destination)
    for (uint256 i = 0; i < count; i += 2) {
      if (i + 1 >= count) break; // Ensure we have a pair

      uint256 sourceGateItemId = GATE_BASE_ITEM_ID + i;
      uint256 destinationGateItemId = GATE_BASE_ITEM_ID + i + 1;

      uint256 sourceGateSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, sourceGateItemId);
      uint256 destinationGateSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, destinationGateItemId);

      LocationData memory sourceGateLocation = LocationData({
        solarSystemId: 1,
        x: 1001 + i,
        y: 1001 + i,
        z: 1001 + i
      });

      LocationData memory destinationGateLocation = LocationData({
        solarSystemId: 1,
        x: 1002 + i,
        y: 1002 + i,
        z: 1002 + i
      });

      EntityRecordParams memory sourceGateEntityRecordParams = EntityRecordParams({
        tenantId: tenantId,
        typeId: smartGateTypeId,
        itemId: sourceGateItemId,
        volume: 10
      });

      EntityRecordParams memory destinationGateEntityRecordParams = EntityRecordParams({
        tenantId: tenantId,
        typeId: smartGateTypeId,
        itemId: destinationGateItemId,
        volume: 10
      });

      // Use the same owner for both gates (accounts[i])
      CreateAndAnchorParams memory sourceGateDeployableParams = CreateAndAnchorParams({
        smartObjectId: sourceGateSmartObjectId,
        assemblyType: "SG",
        entityRecordParams: sourceGateEntityRecordParams,
        owner: accounts[i],
        locationData: sourceGateLocation
      });

      CreateAndAnchorParams memory destinationGateDeployableParams = CreateAndAnchorParams({
        smartObjectId: destinationGateSmartObjectId,
        assemblyType: "SG",
        entityRecordParams: destinationGateEntityRecordParams,
        owner: accounts[i], // Same owner as source gate
        locationData: destinationGateLocation
      });

      smartGateSystem.createAndAnchorGate(sourceGateDeployableParams, 100000000, NETWORK_NODE_ID);
      smartGateSystem.createAndAnchorGate(destinationGateDeployableParams, 100000000, NETWORK_NODE_ID);

      console.log("Created Smart Gate pair for account:", accounts[i]);
    }
  }

  function bringOnlineForAccount(uint256 index, uint256 count, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    uint256 sourceGateSmartObjectId;
    uint256 destinationGateSmartObjectId;

    // Bring SSU online
    uint256 ssuItemId = SSU_BASE_ITEM_ID + index;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);
    deployableSystem.bringOnline(ssuSmartObjectId);

    // Bring Smart Turret online
    uint256 turretItemId = TURRET_BASE_ITEM_ID + index;
    uint256 turretSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, turretItemId);
    deployableSystem.bringOnline(turretSmartObjectId);

    // Bring Smart Gates online (if applicable)
    if (index % 2 == 0 && index + 1 < count) {
      uint256 sourceGateItemId = GATE_BASE_ITEM_ID + index;
      uint256 destinationGateItemId = GATE_BASE_ITEM_ID + index + 1;

      sourceGateSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, sourceGateItemId);
      destinationGateSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, destinationGateItemId);

      // Bring both gates online since they have the same owner
      deployableSystem.bringOnline(sourceGateSmartObjectId);
      deployableSystem.bringOnline(destinationGateSmartObjectId);
      console.log("Brought both gates online for account:", accounts[index]);
    }

    console.log("Brought deployables online for account:", accounts[index]);

    // Log states for all deployables this account owns
    console.log("Deployable state:", uint8(DeployableState.getCurrentState(ssuSmartObjectId)));
    console.log("Deployable state:", uint8(DeployableState.getCurrentState(turretSmartObjectId)));

    // Log gate states if this account owns them
    if (index % 2 == 0 && index + 1 < count) {
      console.log("Source Gate state:", uint8(DeployableState.getCurrentState(sourceGateSmartObjectId)));
      console.log("Destination Gate state:", uint8(DeployableState.getCurrentState(destinationGateSmartObjectId)));
    }
  }

  function registerDelegations(uint256 count, address[] memory accounts, address admin) internal {
    IWorldWithContext world = IWorldWithContext(StoreSwitch.getStoreAddress());

    // Register delegations from each account to the admin
    for (uint256 i = 0; i < count; i++) {
      uint256 accountPrivateKey = derivePrivateKey(i);
      vm.startBroadcast(accountPrivateKey);
      world.registerDelegation(admin, UNLIMITED_DELEGATION, new bytes(0));
      console.log("Registered delegation from account:", accounts[i], "to admin:", admin);
      vm.stopBroadcast();
    }
  }

  function depositToInventoryForAccount(uint256 index, address[] memory accounts) internal {
    bytes32 tenantId = Tenant.get();
    IWorldWithContext world = IWorldWithContext(StoreSwitch.getStoreAddress());

    uint256 ssuItemId = SSU_BASE_ITEM_ID + index;
    uint256 ssuSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, ssuItemId);

    CreateInventoryItemParams[] memory items = new CreateInventoryItemParams[](1);

    uint256 nonSingletonObjectId = ObjectIdLib.calculateNonSingletonId(tenantId, NON_SINGLETON_ITEM_TYPE_ID);

    // Add as non-singleton item
    items[0] = CreateInventoryItemParams({
      smartObjectId: nonSingletonObjectId,
      tenantId: tenantId,
      typeId: NON_SINGLETON_ITEM_TYPE_ID,
      itemId: 0,
      quantity: 9,
      volume: ITEM_VOLUME
    });

    // Call from the character's account but broadcasted by deployer
    world.callFrom(
      accounts[index],
      inventorySystem.toResourceId(),
      abi.encodeCall(InventorySystem.createAndDepositInventory, (ssuSmartObjectId, items))
    );

    console.log("Deposited items to inventory for account:", accounts[index]);
  }
}
