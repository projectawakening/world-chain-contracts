//SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { EveSystem } from "@eveworld/smart-object-framework/src/systems/internal/EveSystem.sol";
import { EntityTable } from "@eveworld/smart-object-framework/src/codegen/tables/EntityTable.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { Utils as SmartObjectFrameworkUtils } from "@eveworld/smart-object-framework/src/utils.sol";
import { ENTITY_RECORD_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_OBJECT_DEPLOYMENT_NAMESPACE, OBJECT } from "@eveworld/common-constants/src/constants.sol";

import { ClassConfig } from "../../../codegen/tables/ClassConfig.sol";
import { LocationTableData } from "../../../codegen/tables/LocationTable.sol";
import { SmartTurretConfigTable } from "../../../codegen/tables/SmartTurretConfigTable.sol";

import { EntityRecordData, WorldPosition } from "../../smart-storage-unit/types.sol";
import { SmartObjectData } from "../../smart-deployable/types.sol";
import { EntityRecordLib } from "../../entity-record/EntityRecordLib.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { SmartDeployableLib } from "../../smart-deployable/SmartDeployableLib.sol";
import { Utils as SmartCharacterUtils } from "../../smart-character/utils.sol";
import { Utils } from "../Utils.sol";
import { Target } from "../types.sol";

contract SmartTurret is EveSystem {
  using WorldResourceIdInstance for ResourceId;
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordLib for EntityRecordLib.World;
  using SmartDeployableLib for SmartDeployableLib.World;
  using SmartObjectFrameworkUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using Utils for bytes14;

  error SmartTurret_UndefinedClassId();

  /**
    * @notice Create and anchor a Smart Turret
    * @param smartTurretId is smart object id of the Smart Turret
    * @param entityRecordData is the entity record data of the Smart Turret
    * @param smartObjectData is the metadata of the Smart Turret
    * @param worldPosition is the x,y,z position of the Smart Turret in space
    * @param fuelUnitVolume is the volume of fuel unit
    * @param fuelConsumptionIntervalInSeconds is one unit of fuel consumption interval is consumed in how many seconds
    // For example:
    // OneFuelUnitConsumptionIntervalInSec = 1; // Consuming 1 unit of fuel every second.
    // OneFuelUnitConsumptionIntervalInSec = 60; // Consuming 1 unit of fuel every minute.
    // OneFuelUnitConsumptionIntervalInSec = 3600; // Consuming 1 unit of fuel every hour.
    * @param fuelMaxCapacity is the maximum capacity of fuel
   */
  function createAndAnchorSmartTurret(
    uint256 smartTurretId,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    WorldPosition memory worldPosition,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) public {
    uint256 classId = ClassConfig.getClassId(_namespace().classConfigTableId(), _systemId());
    if (classId == 0) {
      revert SmartTurret_UndefinedClassId();
    }

    if (EntityTable.getDoesExists(_namespace().entityTableTableId(), smartTurretId) == false) {
      // register smartTurretId as an object
      _smartObjectLib().registerEntity(smartTurretId, OBJECT);
      // tag this object's entity Id to a set of defined classIds
      _smartObjectLib().tagEntity(smartTurretId, classId);
    }

    //Implement the logic to store the data in different modules: EntityRecord, Deployable, Location and ERC721
    _entityRecordLib().createEntityRecord(
      smartTurretId,
      entityRecordData.itemId,
      entityRecordData.typeId,
      entityRecordData.volume
    );

    _smartDeployableLib().registerDeployable(
      smartTurretId,
      smartObjectData,
      fuelUnitVolume,
      fuelConsumptionIntervalInSeconds,
      fuelMaxCapacity
    );
    LocationTableData memory locationData = LocationTableData({
      solarSystemId: worldPosition.solarSystemId,
      x: worldPosition.position.x,
      y: worldPosition.position.y,
      z: worldPosition.position.z
    });
    _smartDeployableLib().anchor(smartTurretId, locationData);
  }

  //function to confirure smart turret
  /**
   * @notice Configure Smart Turret
   * @param smartTurretId is smart object id of the Smart Turret
   * @param systemId is the system id of the Smart Turret logic
   */
  function configureSmartTurret(uint256 smartTurretId, ResourceId systemId) public {
    SmartTurretConfigTable.set(_namespace().smartTurretConfigTableId(), smartTurretId, systemId);
  }

  //view function for turret logic based on proximity
  /**
   * @notice Get the list of targets in proximity
   * @param characterId is the character id of the Smart Turret
   * @param targetQueue is the queue of the Targets in proximity
   * @param remainingAmmo is the remaining ammo of the Smart Turret
   * @param hpRatio is the hp ratio of the Smart Turret
   * ??TODO make sure the smart Turret is online
   */
  function inProximity(
    uint256 smartTurretId,
    uint256 characterId,
    Target[] memory targetQueue,
    uint256 remainingAmmo,
    uint256 hpRatio
  ) public returns (Target[] memory returnTargetQueue) {
    // Delegate the call to the implementation inProximity view function

    ResourceId systemId = SmartTurretConfigTable.get(_namespace().smartTurretConfigTableId(), smartTurretId);

    bytes memory returnData = world().call(
      systemId,
      abi.encodeCall(this.inProximity, (smartTurretId, characterId, targetQueue, remainingAmmo, hpRatio))
    );

    returnTargetQueue = abi.decode(returnData, (Target[]));

    return returnTargetQueue;
  }

  //view function for turrent logic based on agression

  function _entityRecordLib() internal view returns (EntityRecordLib.World memory) {
    return EntityRecordLib.World({ iface: IBaseWorld(_world()), namespace: ENTITY_RECORD_DEPLOYMENT_NAMESPACE });
  }

  function _smartDeployableLib() internal view returns (SmartDeployableLib.World memory) {
    return SmartDeployableLib.World({ iface: IBaseWorld(_world()), namespace: SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE });
  }

  function _smartObjectLib() internal view returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ iface: IBaseWorld(_world()), namespace: SMART_OBJECT_DEPLOYMENT_NAMESPACE });
  }

  function _systemId() internal view returns (ResourceId) {
    return _namespace().smartTurretSystemId();
  }
}
