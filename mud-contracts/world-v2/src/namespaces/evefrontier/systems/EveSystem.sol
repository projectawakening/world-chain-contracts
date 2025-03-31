// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

// MUD core imports
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";

// Local namespace tables
import { Initialize, Tenant } from "../codegen/index.sol";

// Local namespace system imports
import { AccessSystem, accessSystem } from "../codegen/systems/AccessSystemLib.sol";
import { EntityRecordSystem, entityRecordSystem } from "../codegen/systems/EntityRecordSystemLib.sol";
import { DeployableSystem, deployableSystem } from "../codegen/systems/DeployableSystemLib.sol";
import { FuelSystem, fuelSystem } from "../codegen/systems/FuelSystemLib.sol";
import { LocationSystem, locationSystem } from "../codegen/systems/LocationSystemLib.sol";
import { InventorySystem, inventorySystem } from "../codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem, ephemeralInventorySystem } from "../codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystem, inventoryInteractSystem } from "../codegen/systems/InventoryInteractSystemLib.sol";
import { EphemeralInteractSystem, ephemeralInteractSystem } from "../codegen/systems/EphemeralInteractSystemLib.sol";
import { SmartAssemblySystem, smartAssemblySystem } from "../codegen/systems/SmartAssemblySystemLib.sol";
import { SmartCharacterSystem, smartCharacterSystem } from "../codegen/systems/SmartCharacterSystemLib.sol";
import { SmartStorageUnitSystem, smartStorageUnitSystem } from "../codegen/systems/SmartStorageUnitSystemLib.sol";
import { SmartTurretSystem, smartTurretSystem } from "../codegen/systems/SmartTurretSystemLib.sol";
import { SmartGateSystem, smartGateSystem } from "../codegen/systems/SmartGateSystemLib.sol";
import { OwnershipSystem, ownershipSystem } from "../codegen/systems/OwnershipSystemLib.sol";
import { InventoryOwnershipSystem, inventoryOwnershipSystem } from "../codegen/systems/InventoryOwnershipSystemLib.sol";
import { KillMailSystem, killMailSystem } from "../codegen/systems/KillMailSystemLib.sol";

import { Initialize } from "../codegen/index.sol";
import { IEveSystem } from "../interfaces/IEveSystem.sol";

// Local namespace types
import { EntityRecordParams } from "./entity-record/types.sol";

/**
 * @title EveSystem
 * @author CCP Games
 * @notice This is the base configuration system for the evefrontier namespace.
 */
contract EveSystem is IEveSystem, SmartObjectFramework {
  function registerSmartCharacterClass(uint256 typeId, uint256 volume) public {
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = smartCharacterSystem.toResourceId();
    systemIds[1] = entityRecordSystem.toResourceId();
    systemIds[2] = ownershipSystem.toResourceId();
    uint256 classId = initialize(typeId, volume, systemIds);

    ResourceId smartCharacterSystemId = smartCharacterSystem.toResourceId();
    Initialize.set(smartCharacterSystemId, classId);
  }

  function registerSmartStorageUnitClass(uint256 typeId, uint256 volume) public {
    ResourceId[] memory systemIds = new ResourceId[](11);
    systemIds[0] = smartStorageUnitSystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = smartAssemblySystem.toResourceId();
    systemIds[3] = entityRecordSystem.toResourceId();
    systemIds[4] = ownershipSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();
    systemIds[7] = inventorySystem.toResourceId();
    systemIds[8] = ephemeralInventorySystem.toResourceId();
    systemIds[9] = inventoryInteractSystem.toResourceId();
    systemIds[10] = ephemeralInteractSystem.toResourceId();

    uint256 classId = initialize(typeId, volume, systemIds);

    ResourceId smartStorageUnitSystemId = smartStorageUnitSystem.toResourceId();
    Initialize.set(smartStorageUnitSystemId, classId);
  }

  function registerSmartTurretClass(uint256 typeId, uint256 volume) public {
    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = smartTurretSystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = smartAssemblySystem.toResourceId();
    systemIds[3] = entityRecordSystem.toResourceId();
    systemIds[4] = ownershipSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();

    uint256 classId = initialize(typeId, volume, systemIds);

    ResourceId smartTurretSystemId = smartTurretSystem.toResourceId();
    Initialize.set(smartTurretSystemId, classId);
  }

  function registerSmartGateClass(uint256 typeId, uint256 volume) public {
    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = smartGateSystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = smartAssemblySystem.toResourceId();
    systemIds[3] = entityRecordSystem.toResourceId();
    systemIds[4] = ownershipSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();

    uint256 classId = initialize(typeId, volume, systemIds);

    ResourceId smartGateSystemId = smartGateSystem.toResourceId();
    Initialize.set(smartGateSystemId, classId);
  }

  // Configure access for all systems
  // Configure access for EntityRecordSystem
  function configureEntityRecordAccess() public {
    accessConfigSystem.configureAccess(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyCallAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      true
    );

    bytes4[2] memory onlyAdminOrOwnerSelectors = [
      EntityRecordSystem.setDappURL.selector,
      EntityRecordSystem.setDescription.selector
    ];

    for (uint256 i = 0; i < onlyAdminOrOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        entityRecordSystem.toResourceId(),
        onlyAdminOrOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(entityRecordSystem.toResourceId(), onlyAdminOrOwnerSelectors[i], true);
    }

    bytes4[2] memory onlyClassScopedOrCharAdminOrOwnerSelectors = [
      EntityRecordSystem.createMetadata.selector,
      EntityRecordSystem.setName.selector
    ];

    for (uint256 i = 0; i < onlyClassScopedOrCharAdminOrOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        entityRecordSystem.toResourceId(),
        onlyClassScopedOrCharAdminOrOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyClassScopedOrCharAdminOrOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(
        entityRecordSystem.toResourceId(),
        onlyClassScopedOrCharAdminOrOwnerSelectors[i],
        true
      );
    }
  }

  // Configure access for SmartAssemblySystem
  function configureSmartAssemblyAccess() public {
    bytes4[2] memory smartAssemblyOnlyClassScopedSelectors = [
      SmartAssemblySystem.createAssembly.selector,
      SmartAssemblySystem.setAssemblyType.selector
    ];

    for (uint256 i = 0; i < smartAssemblyOnlyClassScopedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartAssemblySystem.toResourceId(),
        smartAssemblyOnlyClassScopedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlySmartAssemblyClassScopedAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(
        smartAssemblySystem.toResourceId(),
        smartAssemblyOnlyClassScopedSelectors[i],
        true
      );
    }

    accessConfigSystem.configureAccess(
      smartAssemblySystem.toResourceId(),
      SmartAssemblySystem.updateAssemblyType.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDirectAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartAssemblySystem.toResourceId(),
      SmartAssemblySystem.updateAssemblyType.selector,
      true
    );
  }

  // Configure access for OwnershipSystem
  function configureOwnershipAccess() public {
    bytes4[4] memory onlyCallAccessWithScopeEnforcedSelectors = [
      OwnershipSystem.assignOwner.selector,
      OwnershipSystem.removeOwner.selector,
      InventoryOwnershipSystem.assignItemToInventory.selector,
      InventoryOwnershipSystem.removeItemFromInventory.selector
    ];

    for (uint256 i = 0; i < onlyCallAccessWithScopeEnforcedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ownershipSystem.toResourceId(),
        onlyCallAccessWithScopeEnforcedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyCallAccessWithScopeEnforced.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ownershipSystem.toResourceId(),
        onlyCallAccessWithScopeEnforcedSelectors[i],
        true
      );
    }
  }

  // Configure access for SmartCharacterSystem
  function configureSmartCharacterAccess() public {
    bytes4[2] memory onlyAdminSupportedSelectors = [
      SmartCharacterSystem.createCharacter.selector,
      SmartCharacterSystem.updateTribeId.selector
    ];

    for (uint256 i = 0; i < onlyAdminSupportedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartCharacterSystem.toResourceId(),
        onlyAdminSupportedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminSupportedAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(
        smartCharacterSystem.toResourceId(),
        onlyAdminSupportedSelectors[i],
        true
      );
    }
    accessConfigSystem.configureAccess(
      smartCharacterSystem.toResourceId(),
      SmartCharacterSystem.removeCharacter.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDirectAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartCharacterSystem.toResourceId(),
      SmartCharacterSystem.removeCharacter.selector,
      true
    );
  }

  // Configure access for LocationSystem
  function configureLocationAccess() public {
    accessConfigSystem.configureAccess(
      locationSystem.toResourceId(),
      LocationSystem.saveLocation.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyClassScopedAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(locationSystem.toResourceId(), LocationSystem.saveLocation.selector, true);
  }

  // Configure access for FuelSystem
  function configureFuelAccess() public {
    bytes4[6] memory fuelOnlyAdminOrClassScopedSelectors = [
      FuelSystem.configureFuelParameters.selector,
      FuelSystem.setFuelUnitVolume.selector,
      FuelSystem.setFuelConsumptionIntervalInSeconds.selector,
      FuelSystem.setFuelAmount.selector,
      FuelSystem.updateFuel.selector,
      FuelSystem.setFuelMaxCapacity.selector
    ];

    for (uint256 i = 0; i < fuelOnlyAdminOrClassScopedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        fuelSystem.toResourceId(),
        fuelOnlyAdminOrClassScopedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrClassScopedAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), fuelOnlyAdminOrClassScopedSelectors[i], true);
    }

    accessConfigSystem.configureAccess(
      fuelSystem.toResourceId(),
      FuelSystem.depositFuel.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), FuelSystem.depositFuel.selector, true);
  }

  // Configure access for DeployableSystem
  function configureDeployableAccess() public {
    bytes4[3] memory onlyDirectAdminSelectors = [
      DeployableSystem.destroyDeployable.selector,
      DeployableSystem.globalPause.selector,
      DeployableSystem.globalResume.selector
    ];

    for (uint256 i = 0; i < onlyDirectAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        onlyDirectAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDirectAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), onlyDirectAdminSelectors[i], true);
      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), onlyDirectAdminSelectors[i], true);
    }

    bytes4[3] memory onlyAdminSupportedSelectors = [
      DeployableSystem.createAndAnchor.selector,
      DeployableSystem.createDeployable.selector,
      DeployableSystem.anchor.selector
    ];

    for (uint256 i = 0; i < onlyAdminSupportedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        onlyAdminSupportedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminSupportedAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), onlyAdminSupportedSelectors[i], true);
    }

    bytes4[1] memory deployableOnlyOwnerWithAdminSupportAccessSelectors = [DeployableSystem.unanchor.selector];

    for (uint256 i = 0; i < deployableOnlyOwnerWithAdminSupportAccessSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        deployableOnlyOwnerWithAdminSupportAccessSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwnerWithAdminSupportAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(
        deployableSystem.toResourceId(),
        deployableOnlyOwnerWithAdminSupportAccessSelectors[i],
        true
      );
    }

    accessConfigSystem.configureAccess(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOnline.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrOwner.selector
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
      AccessSystem.onlyAdminOrOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      deployableSystem.toResourceId(),
      DeployableSystem.bringOffline.selector,
      true
    );
  }

  // Configure access for InventorySystem
  function configureInventoryAccess() public {
    bytes4[2] memory onlyAdminOrClassScopedSelectors = [
      InventorySystem.setCapacity.selector,
      InventorySystem.setEphemeralCapacity.selector
    ];

    for (uint256 i = 0; i < onlyAdminOrClassScopedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        onlyAdminOrClassScopedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrClassScopedAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(inventorySystem.toResourceId(), onlyAdminOrClassScopedSelectors[i], true);
    }

    bytes4[3] memory inventoryOnlyAdminSupportedOwnerOrCallAccessSelectors = [
      InventorySystem.createAndDepositInventory.selector,
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];

    for (uint256 i = 0; i < inventoryOnlyAdminSupportedOwnerOrCallAccessSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        inventoryOnlyAdminSupportedOwnerOrCallAccessSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminSupportedOwnerOrCall.selector
      );
      accessConfigSystem.setAccessEnforcement(
        inventorySystem.toResourceId(),
        inventoryOnlyAdminSupportedOwnerOrCallAccessSelectors[i],
        true
      );
    }
  }

  // Configure access for EphemeralInventorySystem
  function configureEphemeralInventoryAccess() public {
    bytes4[2] memory onlyDirectEphemeralOwnerOrCallAccessSelectors = [
      EphemeralInventorySystem.createAndDepositEphemeral.selector,
      EphemeralInventorySystem.depositEphemeral.selector
    ];

    for (uint256 i = 0; i < onlyDirectEphemeralOwnerOrCallAccessSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInventorySystem.toResourceId(),
        onlyDirectEphemeralOwnerOrCallAccessSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDirectEphemeralOwnerOrCall.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInventorySystem.toResourceId(),
        onlyDirectEphemeralOwnerOrCallAccessSelectors[i],
        true
      );
    }
    accessConfigSystem.configureAccess(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.withdrawEphemeral.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyCallAccessOrDirectEphemeralOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInventorySystem.toResourceId(),
      EphemeralInventorySystem.withdrawEphemeral.selector,
      true
    );
  }

  // Configure access for EphemralInteractSystem
  function configureEphemeralInteractAccess() public {
    accessConfigSystem.configureAccess(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.transferToEphemeral.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwnerOrEphemeralTransferRole.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.transferToEphemeral.selector,
      true
    );

    accessConfigSystem.configureAccess(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.transferFromEphemeral.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyEphemeralTransferRole.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.transferFromEphemeral.selector,
      true
    );

    accessConfigSystem.configureAccess(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.crossTransferToEphemeral.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwnerOrEphemeralCrossTransferRole.selector
    );
    accessConfigSystem.setAccessEnforcement(
      ephemeralInteractSystem.toResourceId(),
      EphemeralInteractSystem.crossTransferToEphemeral.selector,
      true
    );

    bytes4[3] memory ephemeralInteractOnlyOwnerSelectors = [
      EphemeralInteractSystem.setTransferFromEphemeralAccess.selector,
      EphemeralInteractSystem.setTransferToEphemeralAccess.selector,
      EphemeralInteractSystem.setCrossTransferToEphemeralAccess.selector
    ];
    for (uint256 i = 0; i < ephemeralInteractOnlyOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyDirectOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerSelectors[i],
        true
      );
    }
  }

  // Configure access for InventoryInteractSystem
  function configureInventoryInteractAccess() public {
    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.transferToInventory.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwnerOrInventoryTransferRole.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.transferToInventory.selector,
      true
    );

    accessConfigSystem.configureAccess(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setTransferToInventoryAccess.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyDirectOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      inventoryInteractSystem.toResourceId(),
      InventoryInteractSystem.setTransferToInventoryAccess.selector,
      true
    );
  }

  // Configure access for SmartStorageUnitSystem
  function configureSmartStorageUnitAccess() public {
    accessConfigSystem.configureAccess(
      smartStorageUnitSystem.toResourceId(),
      SmartStorageUnitSystem.createAndAnchorStorageUnit.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminSupportedAccess.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartStorageUnitSystem.toResourceId(),
      SmartStorageUnitSystem.createAndAnchorStorageUnit.selector,
      true
    );
  }

  // Configure access for SmartTurretSystem
  function configureSmartTurretAccess() public {
    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminSupportedAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.createAndAnchorTurret.selector,
      true
    );

    accessConfigSystem.configureAccess(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureTurret.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyOwner.selector
    );

    accessConfigSystem.setAccessEnforcement(
      smartTurretSystem.toResourceId(),
      SmartTurretSystem.configureTurret.selector,
      true
    );
  }

  // Configure access for SmartGateSystem
  function configureSmartGateAccess() public {
    // create and anchor gate - only admin supported
    accessConfigSystem.configureAccess(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorGate.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminSupportedAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorGate.selector,
      true
    );
    // configure gate - system supported or direct call by owner
    accessConfigSystem.configureAccess(
      smartGateSystem.toResourceId(),
      SmartGateSystem.configureGate.selector,
      accessSystem.toResourceId(),
      AccessSystem.adminSupportOrDirectOwner.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartGateSystem.toResourceId(),
      SmartGateSystem.configureGate.selector,
      true
    );
    // link and unlink gates - admin supported or direct call by owner of both gates
    bytes4[2] memory adminSupportedOrDirectOwnerGatesSelectors = [
      SmartGateSystem.linkGates.selector,
      SmartGateSystem.unlinkGates.selector
    ];

    for (uint256 i = 0; i < adminSupportedOrDirectOwnerGatesSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartGateSystem.toResourceId(),
        adminSupportedOrDirectOwnerGatesSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.adminSupportOrDirectOwnerGates.selector
      );
      accessConfigSystem.setAccessEnforcement(
        smartGateSystem.toResourceId(),
        adminSupportedOrDirectOwnerGatesSelectors[i],
        true
      );
    }
  }

  // Configure access for KillMailSystem
  function configureKillMailAccess() public {
    accessConfigSystem.configureAccess(
      killMailSystem.toResourceId(),
      KillMailSystem.reportKill.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminSupportedAccess.selector
    );

    accessConfigSystem.setAccessEnforcement(killMailSystem.toResourceId(), KillMailSystem.reportKill.selector, true);
  }

  /**
   * @notice Initialize a class by registering creating a class id and registering the systems that belong to it
   * @param typeId The type id of the system
   * @param systemIds The system ids that belong to the class
   */
  function initialize(uint256 typeId, uint256 volume, ResourceId[] memory systemIds) internal returns (uint256) {
    if (typeId == 0) revert("Invalid typeId");
    uint256 classId = uint256(keccak256(abi.encodePacked(Tenant.get(), typeId)));
    entitySystem.scopedRegisterClass(classId, _callMsgSender(1), systemIds);
    entityRecordSystem.createRecord(
      classId,
      EntityRecordParams({ tenantId: Tenant.get(), itemId: 0, typeId: typeId, volume: volume })
    );
    return classId;
  }
}
