pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { GlobalDeployableState } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/GlobalDeployableState.sol";
import { LocationData } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/Location.sol";
import { Characters } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/Characters.sol";
import { CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/tables/CharactersByAccount.sol";
import { EntityRecordData, EntityMetadata } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";
import { DeployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/DeployableSystem.sol";
import { SmartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { State, SmartObjectData } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";
import { SmartStorageUnitSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { Coord, WorldPosition } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/location/types.sol";

import { smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartCharacterSystemLib.sol";
import { deployableSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/DeployableSystemLib.sol";
import { smartStorageUnitSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/systems/SmartStorageUnitSystemLib.sol";

import { CreateAndAnchorDeployableParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/deployable/types.sol";

import { SMART_STORAGE_UNIT } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/constants.sol";

contract AnchorSSU is Script {
  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address player = vm.addr(deployerPrivateKey);

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);

    uint256 characterId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-2345")));
    address characterAddress = player;
    uint256 tribeId = 100;
    EntityRecordData memory entityRecord = EntityRecordData({ typeId: 123, itemId: 234, volume: 100 });

    EntityMetadata memory entityRecordMetadata = EntityMetadata({
      name: "name",
      dappURL: "dappURL",
      description: "description"
    });

    if (
      Characters.getCharacterAddress(characterId) == address(0) &&
      CharactersByAccount.getCharacterId(characterAddress) == 0
    ) {
      smartCharacterSystem.createCharacter(characterId, characterAddress, tribeId, entityRecord, entityRecordMetadata);
    }

    // check global state and resume if needed
    if (GlobalDeployableState.getIsPaused() == false) {
      deployableSystem.globalResume();
    }

    uint256 smartObjectId = uint256(keccak256(abi.encode("item:<tenant_id>-<db_id>-00001")));
    SmartObjectData memory smartObjectData = SmartObjectData({ owner: player, tokenURI: "test" });
    LocationData memory locationData = LocationData({ solarSystemId: 1, x: 1, y: 1, z: 1 });

    CreateAndAnchorDeployableParams memory params = CreateAndAnchorDeployableParams({
      smartObjectId: smartObjectId,
      smartAssemblyType: SMART_STORAGE_UNIT,
      entityRecordData: entityRecord,
      smartObjectData: smartObjectData,
      fuelUnitVolume: 10,
      fuelConsumptionIntervalInSeconds: 3600,
      fuelMaxCapacity: 1000000000,
      locationData: locationData
    });

    smartStorageUnitSystem.createAndAnchorSmartStorageUnit(params, 1000000000, 1000000000);

    vm.stopBroadcast();
  }
}
