pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Tenant, LocationData } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";
import { SmartTurretSystem, smartTurretSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartTurretSystemLib.sol";
import { CreateAndAnchorParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract AnchorSmartTurret is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 alicePrivateKey = vm.deriveKey(mnemonic, 2);
    address alice = vm.addr(alicePrivateKey);
    uint256 bobPrivateKey = vm.deriveKey(mnemonic, 3);
    address bob = vm.addr(bobPrivateKey);
    uint256 charliePrivateKey = vm.deriveKey(mnemonic, 4);
    address charlie = vm.addr(charliePrivateKey);

    bytes32 tenantId = Tenant.get();
    uint256 smartTurretTypeId = vm.envUint("TURRET_TYPE_ID");
    uint256 aliceSmartTurretItemId = 1559;
    uint256 bobSmartTurretItemId = 1560;
    uint256 charlieSmartTurretItemId = 1561;

    uint256 aliceSmartTurretSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, aliceSmartTurretItemId);
    uint256 bobSmartTurretSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, bobSmartTurretItemId);
    uint256 charlieSmartTurretSmartObjectId = ObjectIdLib.calculateObjectId(tenantId, charlieSmartTurretItemId);

    EntityRecordParams memory aliceSmartTurretEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartTurretTypeId,
      itemId: aliceSmartTurretItemId,
      volume: 10
    });
    EntityRecordParams memory bobSmartTurretEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartTurretTypeId,
      itemId: bobSmartTurretItemId,
      volume: 10
    });
    EntityRecordParams memory charlieSmartTurretEntityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: smartTurretTypeId,
      itemId: charlieSmartTurretItemId,
      volume: 10
    });

    vm.startBroadcast(deployerPrivateKey);

    createAndAnchorTurret(aliceSmartTurretSmartObjectId, aliceSmartTurretEntityRecordParams, alice);
    createAndAnchorTurret(bobSmartTurretSmartObjectId, bobSmartTurretEntityRecordParams, bob);
    createAndAnchorTurret(charlieSmartTurretSmartObjectId, charlieSmartTurretEntityRecordParams, charlie);

    vm.stopBroadcast();
  }

  function createAndAnchorTurret(
    uint256 smartTurretSmartObjectId,
    EntityRecordParams memory entityRecordParams,
    address owner
  ) public {
    uint256 networkNodeId = 0;
    LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1001, y: 1001, z: 1001 });
    CreateAndAnchorParams memory deployableParams = CreateAndAnchorParams({
      smartObjectId: smartTurretSmartObjectId,
      assemblyType: "ST",
      entityRecordParams: entityRecordParams,
      owner: owner,
      locationData: locationData
    });

    smartTurretSystem.createAndAnchorTurret(deployableParams, networkNodeId);
  }
}
