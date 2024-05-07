// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";

import "@eve/common-constants/src/constants.sol";

import { Utils as EntityRecordUtils } from "../modules/entity-record/Utils.sol";
import { ENTITY_RECORD_MODULE_NAME } from "../modules/entity-record/constants.sol";
import { Utils as StaticDataUtils } from "../modules/static-data/Utils.sol";
import { STATIC_DATA_MODULE_NAME } from "../modules/static-data/constants.sol";
import { Utils as LocationUtils } from "../modules/location/Utils.sol";
import { LOCATION_MODULE_NAME } from "../modules/location/constants.sol";
import { Utils as SmartCharacterUtils } from "../modules/smart-character/Utils.sol";
import { SMART_CHARACTER_MODULE_NAME } from "../modules/smart-character/constants.sol";
import { Utils as SmartDeployableUtils } from "../modules/smart-deployable/Utils.sol";
import { SMART_DEPLOYABLE_MODULE_NAME } from "../modules/smart-deployable/constants.sol";
import { Utils as InventoryUtils } from "../modules/inventory/Utils.sol";
import { INVENTORY_MODULE_NAME } from "../modules/inventory/constants.sol";
import { Utils as SSUUtils } from "../modules/smart-storage-unit/Utils.sol";
import { SMART_STORAGE_MODULE_NAME } from "../modules/smart-storage-unit/constants.sol";

import { SmartObjectLib } from "@eve/frontier-smart-object-framework/src/SmartObjectLib.sol";

library ModulesInitializationLibrary {
  using SmartObjectLib for SmartObjectLib.World;
  using EntityRecordUtils for bytes14;
  using StaticDataUtils for bytes14;
  using LocationUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using InventoryUtils for bytes14;
  using SSUUtils for bytes14;

  function initEntityRecord(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME),
      ENTITY_RECORD_MODULE_NAME,
      ENTITY_RECORD_DEPLOYMENT_NAMESPACE.entityRecordSystemId()
    );
  }

  function associateEntityRecord(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME)
    );
  }

  function initStaticData(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME),
      STATIC_DATA_MODULE_NAME,
      STATIC_DATA_DEPLOYMENT_NAMESPACE.staticDataSystemId()
    );
  }

  function associateStaticData(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME)
    );
  }

  function initLocation(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME),
      LOCATION_MODULE_NAME,
      LOCATION_DEPLOYMENT_NAMESPACE.locationSystemId()
    );
  }

  function associateLocation(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME)
    );
  }

  function initSmartCharacter(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(SMART_CHARACTER_DEPLOYMENT_NAMESPACE, SMART_CHARACTER_MODULE_NAME),
      SMART_CHARACTER_MODULE_NAME,
      SMART_CHARACTER_DEPLOYMENT_NAMESPACE.smartCharacterSystemId()
    );
  }

  function associateSmartCharacter(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(SMART_CHARACTER_DEPLOYMENT_NAMESPACE, SMART_CHARACTER_MODULE_NAME)
    );
  }

  function initSmartDeployable(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME),
      SMART_DEPLOYABLE_MODULE_NAME,
      SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE.smartDeployableSystemId()
    );
  }

  function associateSmartDeployable(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME)
    );
  }

  function initInventory(IBaseWorld world) internal {
    ResourceId[] memory systemIds = new ResourceId[](2);
    systemIds[0] = INVENTORY_DEPLOYMENT_NAMESPACE.inventorySystemId();
    systemIds[1] = INVENTORY_DEPLOYMENT_NAMESPACE.ephemeralInventorySystemId();
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModules(
      _moduleId(INVENTORY_DEPLOYMENT_NAMESPACE, INVENTORY_MODULE_NAME),
      INVENTORY_MODULE_NAME,
      systemIds
    );
  }

  function associateInventory(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(INVENTORY_DEPLOYMENT_NAMESPACE, INVENTORY_MODULE_NAME)
    );
  }

  function initSSU(IBaseWorld world) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).registerEVEModule(
      _moduleId(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_STORAGE_MODULE_NAME),
      SMART_STORAGE_MODULE_NAME,
      SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId()
    );
  }

  function associateSSU(IBaseWorld world, uint256 entityId) internal {
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModule(
      entityId,
      _moduleId(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_STORAGE_MODULE_NAME)
    );
  }

  function registerAndAssociateTypeIdToDeployable(
    IBaseWorld world,
    uint256 frontierTypeId
  ) internal returns (uint256 classId) {
    uint256[] memory moduleIds = new uint256[](4);
    moduleIds[0] = _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME);
    moduleIds[1] = _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME);
    moduleIds[2] = _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME);
    classId = _typeIdToClassId(frontierTypeId);
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModules(classId, moduleIds);
  }

  function associateClassIdToDeployable(IBaseWorld world, uint256 classId) internal {
    uint256[] memory moduleIds = new uint256[](4);
    moduleIds[0] = _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME);
    moduleIds[1] = _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME);
    moduleIds[2] = _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME);
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModules(classId, moduleIds);
  }

  function registerAndAssociateTypeIdToSSU(
    IBaseWorld world,
    uint256 frontierTypeId
  ) internal returns (uint256 classId) {
    uint256[] memory moduleIds = new uint256[](5);
    moduleIds[0] = _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME);
    moduleIds[1] = _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME);
    moduleIds[2] = _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_STORAGE_MODULE_NAME);
    classId = _typeIdToClassId(frontierTypeId);
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModules(classId, moduleIds);
  }

  function associateClassIdToSSU(IBaseWorld world, uint256 classId) internal {
    uint256[] memory moduleIds = new uint256[](5);
    moduleIds[0] = _moduleId(STATIC_DATA_DEPLOYMENT_NAMESPACE, STATIC_DATA_MODULE_NAME);
    moduleIds[1] = _moduleId(ENTITY_RECORD_DEPLOYMENT_NAMESPACE, ENTITY_RECORD_MODULE_NAME);
    moduleIds[2] = _moduleId(LOCATION_DEPLOYMENT_NAMESPACE, LOCATION_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_DEPLOYABLE_DEPLOYMENT_NAMESPACE, SMART_DEPLOYABLE_MODULE_NAME);
    moduleIds[3] = _moduleId(SMART_STORAGE_UNIT_DEPLOYMENT_NAMESPACE, SMART_STORAGE_MODULE_NAME);
    _sofLib(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE).associateModules(classId, moduleIds);
  }

  function _sofLib(IBaseWorld world, bytes14 namespace) internal pure returns (SmartObjectLib.World memory) {
    return SmartObjectLib.World({ namespace: namespace, iface: world });
  }

  function _moduleId(bytes14 moduleNamespace, bytes16 moduleName) internal pure returns (uint256) {
    return uint256(ResourceId.unwrap(WorldResourceIdLib.encode(RESOURCE_SYSTEM, moduleNamespace, moduleName)));
  }

  function _typeIdToClassId(uint256 frontierTypeId) internal pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked("item:", _uintToStr(frontierTypeId))));
  }

  // Helper function to convert a uint256 to a string
  function _uintToStr(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    j = _i;
    while (j != 0) {
      bstr[--k] = bytes1(uint8(48 + (j % 10)));
      j /= 10;
    }
    return string(bstr);
  }
}
