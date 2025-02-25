// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";

import { AccessSystem } from "../systems/access-systems/AccessSystem.sol";
import { accessSystem } from "../codegen/systems/AccessSystemLib.sol";

import { StaticDataSystem } from "../systems/static-data/StaticDataSystem.sol";
import { staticDataSystem } from "../codegen/systems/StaticDataSystemLib.sol";
import { EntityRecordSystem } from "../systems/entity-record/EntityRecordSystem.sol";
import { entityRecordSystem } from "../codegen/systems/EntityRecordSystemLib.sol";
import { DeployableSystem } from "../systems/deployable/DeployableSystem.sol";
import { deployableSystem } from "../codegen/systems/DeployableSystemLib.sol";
import { FuelSystem } from "../systems/fuel/FuelSystem.sol";
import { fuelSystem } from "../codegen/systems/FuelSystemLib.sol";
import { LocationSystem } from "../systems/location/LocationSystem.sol";
import { locationSystem } from "../codegen/systems/LocationSystemLib.sol";
import { InventorySystem } from "../systems/inventory/InventorySystem.sol";
import { inventorySystem } from "../codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem } from "../systems/inventory/EphemeralInventorySystem.sol";
import { ephemeralInventorySystem } from "../codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystem } from "../systems/inventory/InventoryInteractSystem.sol";
import { inventoryInteractSystem } from "../codegen/systems/InventoryInteractSystemLib.sol";
import { SmartAssemblySystem } from "../systems/smart-assembly/SmartAssemblySystem.sol";
import { smartAssemblySystem } from "../codegen/systems/SmartAssemblySystemLib.sol";
import { SmartCharacterSystem } from "../systems/smart-character/SmartCharacterSystem.sol";
import { smartCharacterSystem } from "../codegen/systems/SmartCharacterSystemLib.sol";
import { SmartStorageUnitSystem } from "../systems/smart-storage-unit/SmartStorageUnitSystem.sol";
import { smartStorageUnitSystem } from "../codegen/systems/SmartStorageUnitSystemLib.sol";
import { SmartTurretSystem } from "../systems/smart-turret/SmartTurretSystem.sol";
import { smartTurretSystem } from "../codegen/systems/SmartTurretSystemLib.sol";
import { SmartGateSystem } from "../systems/smart-gate/SmartGateSystem.sol";
import { smartGateSystem } from "../codegen/systems/SmartGateSystemLib.sol";
import { Initialize } from "../codegen/index.sol";

/**
 * @title EveSystem
 * @author CCP Games
 * @notice This is the base system to be inherited by all other systems.
 * @dev Consider combining this with the SmartObjectSystem which is extended by all systems.
 */
contract EveSystem is SmartObjectFramework {
  /**
   * @notice Get the world instance
   * @return The IWorld instance
   */
  function world() internal view returns (IWorldWithContext) {
    return IWorldWithContext(_world());
  }

  function registerSmartCharacterClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](2);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = smartCharacterSystem.toResourceId();
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartCharacterSystemId = smartCharacterSystem.toResourceId();
    Initialize.set(smartCharacterSystemId, classId);
  }

  function registerSmartStorageUnitClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](9);
    systemIds[0] = inventorySystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = ephemeralInventorySystem.toResourceId();
    systemIds[3] = inventoryInteractSystem.toResourceId();
    systemIds[4] = entityRecordSystem.toResourceId();
    systemIds[5] = smartStorageUnitSystem.toResourceId();
    systemIds[6] = smartAssemblySystem.toResourceId();
    systemIds[7] = fuelSystem.toResourceId();
    systemIds[8] = locationSystem.toResourceId();
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartStorageUnitSystemId = smartStorageUnitSystem.toResourceId();
    Initialize.set(smartStorageUnitSystemId, classId);
  }

  function registerSmartTurretClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = smartTurretSystem.toResourceId();
    systemIds[2] = fuelSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = deployableSystem.toResourceId();
    systemIds[5] = smartAssemblySystem.toResourceId();
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartTurretSystemId = smartTurretSystem.toResourceId();
    Initialize.set(smartTurretSystemId, classId);
  }

  function registerSmartGateClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](6);
    systemIds[0] = entityRecordSystem.toResourceId();
    systemIds[1] = smartGateSystem.toResourceId();
    systemIds[2] = fuelSystem.toResourceId();
    systemIds[3] = locationSystem.toResourceId();
    systemIds[4] = deployableSystem.toResourceId();
    systemIds[5] = smartAssemblySystem.toResourceId();
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartGateSystemId = smartGateSystem.toResourceId();
    Initialize.set(smartGateSystemId, classId);
  }

  // Configure access for all systems
  // Configure access for EntityRecordSystem
  function configureEntityRecordAccess() public {
    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecord.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createEntityRecord.selector,
      true
    );

    bytes4[4] memory onlyAdminOrDeployableOwnerSelectors = [
      EntityRecordSystem.createEntityRecordMetadata.selector,
      EntityRecordSystem.setName.selector,
      EntityRecordSystem.setDappURL.selector,
      EntityRecordSystem.setDescription.selector
    ];

    for (uint256 i = 0; i < onlyAdminOrDeployableOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        entityRecordSystem.toResourceId(),
        onlyAdminOrDeployableOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrDeployableOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(
        entityRecordSystem.toResourceId(),
        onlyAdminOrDeployableOwnerSelectors[i],
        true
      );
    }
  }

  // Configure access for StaticDataSystem
  function configureStaticDataAccess() public {
    bytes4[2] memory onlyAdminSelectors = [StaticDataSystem.setCid.selector, StaticDataSystem.setBaseURI.selector];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        staticDataSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(staticDataSystem.toResourceId(), onlyAdminSelectors[i], true);
    }
  }

  // Configure access for SmartAssemblySystem
  function configureSmartAssemblyAccess() public {
    bytes4[3] memory onlyAdminSelectors = [
      SmartAssemblySystem.createSmartAssembly.selector,
      SmartAssemblySystem.setSmartAssemblyType.selector,
      SmartAssemblySystem.updateSmartAssemblyType.selector
    ];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartAssemblySystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(smartAssemblySystem.toResourceId(), onlyAdminSelectors[i], true);
    }
  }

  // Configure access for SmartCharacterSystem
  function configureSmartCharacterAccess() public {
    bytes4[3] memory onlyAdminSelectors = [
      SmartCharacterSystem.registerCharacterToken.selector,
      SmartCharacterSystem.updateTribeId.selector,
      SmartCharacterSystem.createCharacter.selector
    ];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartCharacterSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(smartCharacterSystem.toResourceId(), onlyAdminSelectors[i], true);
    }
  }

  // Configure access for LocationSystem
  function configureLocationAccess() public {
    accessConfigSystem.configureAccess(
      locationSystem.toResourceId(),
      LocationSystem.saveLocation.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(locationSystem.toResourceId(), LocationSystem.saveLocation.selector, true);
  }

  // Configure access for FuelSystem
  function configureFuelAccess() public {
    bytes4[8] memory onlyAdminSelectors = [
      FuelSystem.configureFuelParameters.selector,
      FuelSystem.setFuelUnitVolume.selector,
      FuelSystem.setFuelConsumptionIntervalInSeconds.selector,
      FuelSystem.setFuelMaxCapacity.selector,
      FuelSystem.setFuelAmount.selector,
      FuelSystem.depositFuel.selector,
      FuelSystem.withdrawFuel.selector,
      FuelSystem.updateFuel.selector
    ];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        fuelSystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), onlyAdminSelectors[i], true);
    }
  }

  // Configure access for DeployableSystem
  function configureDeployableAccess() public {
    bytes4[8] memory deployableSignatures = [
      DeployableSystem.createAndAnchorDeployable.selector,
      DeployableSystem.registerDeployable.selector,
      DeployableSystem.registerDeployableToken.selector,
      DeployableSystem.destroyDeployable.selector,
      DeployableSystem.anchor.selector,
      DeployableSystem.unanchor.selector,
      DeployableSystem.globalPause.selector,
      DeployableSystem.globalResume.selector
    ];

    for (uint256 i = 0; i < deployableSignatures.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        deployableSignatures[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), deployableSignatures[i], true);
    }

    accessConfigSystem.configureAccess(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOnline.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOnline.selector,
      true
    );

    accessConfigSystem.configureAccess(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOffline.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrDeployableOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOffline.selector,
      true
    );
  }

  // Configure access for InventorySystem
  function configureInventoryAccess() public {
    bytes4[2] memory onlyAdminSelectors = [
      InventorySystem.setInventoryCapacity.selector,
      InventorySystem.createAndDepositItemsToInventory.selector
    ];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(inventorySystem.toResourceId(), onlyAdminSelectors[i], true);
    }

    bytes4[2] memory onlyOwnerOrInvInteractSelectors = [
      InventorySystem.depositToInventory.selector,
      InventorySystem.withdrawFromInventory.selector
    ];

    for (uint256 i = 0; i < onlyOwnerOrInvInteractSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        onlyOwnerOrInvInteractSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
      );
      accessConfigSystem.setAccessEnforcement(inventorySystem.toResourceId(), onlyOwnerOrInvInteractSelectors[i], true);
    }
  }

  // Configure access for EphemeralInventorySystem
  function configureEphemeralInventoryAccess() public {
    bytes4[2] memory onlyAdminSelectors = [
      EphemeralInventorySystem.setEphemeralInventoryCapacity.selector,
      EphemeralInventorySystem.createAndDepositItemsToEphemeralInventory.selector
    ];

    for (uint256 i = 0; i < onlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInventorySystem.toResourceId(),
        onlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(ephemeralInventorySystem.toResourceId(), onlyAdminSelectors[i], true);
    }

    bytes4[2] memory onlyOwnerOrInvInteractSelectors = [
      EphemeralInventorySystem.depositToEphemeralInventory.selector,
      EphemeralInventorySystem.withdrawFromEphemeralInventory.selector
    ];

    for (uint256 i = 0; i < onlyOwnerOrInvInteractSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInventorySystem.toResourceId(),
        onlyOwnerOrInvInteractSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDeployableOwnerOrInventoryInteractSystem.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInventorySystem.toResourceId(),
        onlyOwnerOrInvInteractSelectors[i],
        true
      );
    }
  }

  // Configure access for InventoryInteractSystem
  function configureInventoryInteractAccess() public {
    //TODO after checking with the team
  }

  // Configure access for SmartStorageUnitSystem
  function configureSmartStorageUnitAccess() public {
    accessConfigSystem.configureAccess(
      smartStorageUnitSystem.toResourceId(),
      SmartStorageUnitSystem.createAndAnchorSmartStorageUnit.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartStorageUnitSystem.toResourceId(),
      SmartStorageUnitSystem.createAndAnchorSmartStorageUnit.selector,
      true
    );
  }

  // Configure access for SmartTurretSystem
  function configureSmartTurretAccess() public {
    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorSmartTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorSmartTurret.selector,
      true
    );

    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureSmartTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDeployableOwner.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureSmartTurret.selector,
      true
    );
  }

  // Configure access for SmartGateSystem
  function configureSmartGateAccess() public {
    accessConfigSystem.configureAccess(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorSmartGate.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorSmartGate.selector,
      true
    );

    bytes4[3] memory onlyOwnerSelectors = [
      SmartGateSystem.configureSmartGate.selector,
      SmartGateSystem.linkSmartGates.selector,
      SmartGateSystem.unlinkSmartGates.selector
    ];

    for (uint256 i = 0; i < onlyOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartGateSystem.toResourceId(),
        onlyOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDeployableOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(smartGateSystem.toResourceId(), onlyOwnerSelectors[i], true);
    }
  }

  /**
   * @notice Initialize a class by registering creating a class id and registering the systems that belong to it
   * @param typeId The type id of the system
   * @param systemIds The system ids that belong to the class
   */
  function initialize(uint256 typeId, ResourceId[] memory systemIds) internal returns (uint256) {
    if (typeId == 0) revert("Invalid typeId");
    uint256 classId = uint256(keccak256(abi.encodePacked(typeId)));
    entitySystem.registerClass(classId, systemIds);

    //Create access role for this class and add the _callMsgSender(1) as a memeber by calling RoleManagementSystem.scopedCreateRole()
    bytes32 adminRole = bytes32("ADMIN_ROLE");
    roleManagementSystem.scopedCreateRole(classId, adminRole, adminRole, _callMsgSender(1));

    return classId;
  }
}
