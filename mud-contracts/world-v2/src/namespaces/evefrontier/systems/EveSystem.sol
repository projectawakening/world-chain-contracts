// SPDX-License-Identifier: MIT

pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";
import { roleManagementSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { entitySystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { accessConfigSystem } from "@eveworld/smart-object-framework-v2/src/namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";

import { AccessSystem } from "./access-system/AccessSystem.sol";
import { accessSystem } from "../codegen/systems/AccessSystemLib.sol";

import { EntityRecordSystem } from "./entity-record/EntityRecordSystem.sol";
import { entityRecordSystem } from "../codegen/systems/EntityRecordSystemLib.sol";
import { DeployableSystem } from "./deployable/DeployableSystem.sol";
import { deployableSystem } from "../codegen/systems/DeployableSystemLib.sol";
import { FuelSystem } from "./fuel/FuelSystem.sol";
import { fuelSystem } from "../codegen/systems/FuelSystemLib.sol";
import { LocationSystem } from "./location/LocationSystem.sol";
import { locationSystem } from "../codegen/systems/LocationSystemLib.sol";
import { InventorySystem } from "./inventory/InventorySystem.sol";
import { inventorySystem } from "../codegen/systems/InventorySystemLib.sol";
import { EphemeralInventorySystem } from "./inventory/EphemeralInventorySystem.sol";
import { ephemeralInventorySystem } from "../codegen/systems/EphemeralInventorySystemLib.sol";
import { InventoryInteractSystem } from "./inventory/InventoryInteractSystem.sol";
import { inventoryInteractSystem } from "../codegen/systems/InventoryInteractSystemLib.sol";
import { SmartAssemblySystem } from "./smart-assembly/SmartAssemblySystem.sol";
import { smartAssemblySystem } from "../codegen/systems/SmartAssemblySystemLib.sol";
import { SmartCharacterSystem } from "./smart-character/SmartCharacterSystem.sol";
import { smartCharacterSystem } from "../codegen/systems/SmartCharacterSystemLib.sol";
import { SmartStorageUnitSystem } from "./smart-storage-unit/SmartStorageUnitSystem.sol";
import { smartStorageUnitSystem } from "../codegen/systems/SmartStorageUnitSystemLib.sol";
import { SmartTurretSystem } from "./smart-turret/SmartTurretSystem.sol";
import { smartTurretSystem } from "../codegen/systems/SmartTurretSystemLib.sol";
import { SmartGateSystem } from "./smart-gate/SmartGateSystem.sol";
import { smartGateSystem } from "../codegen/systems/SmartGateSystemLib.sol";
import { OwnershipSystem } from "./ownership/OwnershipSystem.sol";
import { ownershipSystem } from "../codegen/systems/OwnershipSystemLib.sol";
import { Initialize } from "../codegen/index.sol";
import { IEveSystem } from "../interfaces/IEveSystem.sol";
import { EphemeralInteractSystem } from "./inventory/EphemeralInteractSystem.sol";
import { ephemeralInteractSystem } from "../codegen/systems/EphemeralInteractSystemLib.sol";

/**
 * @title EveSystem
 * @author CCP Games
 * @notice This is the base system to be inherited by all other systems.
 * @dev Consider combining this with the SmartObjectSystem which is extended by all systems.
 */
contract EveSystem is IEveSystem, SmartObjectFramework {
  function registerSmartCharacterClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](3);
    systemIds[0] = smartCharacterSystem.toResourceId();
    systemIds[1] = entityRecordSystem.toResourceId();
    systemIds[2] = ownershipSystem.toResourceId();
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartCharacterSystemId = smartCharacterSystem.toResourceId();
    Initialize.set(smartCharacterSystemId, classId);
  }

  function registerSmartStorageUnitClass(uint256 typeId) public {
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
    
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartStorageUnitSystemId = smartStorageUnitSystem.toResourceId();
    Initialize.set(smartStorageUnitSystemId, classId);
  }

  function registerSmartTurretClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = smartTurretSystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = smartAssemblySystem.toResourceId();
    systemIds[3] = entityRecordSystem.toResourceId();
    systemIds[4] = ownershipSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();
    
    uint256 classId = initialize(typeId, systemIds);

    ResourceId smartTurretSystemId = smartTurretSystem.toResourceId();
    Initialize.set(smartTurretSystemId, classId);
  }

  function registerSmartGateClass(uint256 typeId) public {
    ResourceId[] memory systemIds = new ResourceId[](7);
    systemIds[0] = smartGateSystem.toResourceId();
    systemIds[1] = deployableSystem.toResourceId();
    systemIds[2] = smartAssemblySystem.toResourceId();
    systemIds[3] = entityRecordSystem.toResourceId();
    systemIds[4] = ownershipSystem.toResourceId();
    systemIds[5] = fuelSystem.toResourceId();
    systemIds[6] = locationSystem.toResourceId();
    
    uint256 classId = initialize(typeId, systemIds);

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
      AccessSystem.onlyDirectAdminOrCallAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(
      entityRecordSystem.toResourceId(),
      EntityRecordSystem.createRecord.selector,
      true
    );

    bytes4[2] memory entityRecordOnlyAdminOrOwnerSelectors = [
      EntityRecordSystem.setDappURL.selector,
      EntityRecordSystem.setDescription.selector
    ];

    for (uint256 i = 0; i < entityRecordOnlyAdminOrOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        entityRecordSystem.toResourceId(),
        entityRecordOnlyAdminOrOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(
        entityRecordSystem.toResourceId(),
        entityRecordOnlyAdminOrOwnerSelectors[i],
        true
      );
    }

    bytes4[2] memory entityRecordOnlyAdminForCharactersOtherwiseAlsoOwnerSelectors = [
      EntityRecordSystem.createMetadata.selector,
      EntityRecordSystem.setName.selector
    ];

    for (uint256 i = 0; i < entityRecordOnlyAdminForCharactersOtherwiseAlsoOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        entityRecordSystem.toResourceId(),
        entityRecordOnlyAdminForCharactersOtherwiseAlsoOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminForCharactersOtherwiseAlsoOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(
        entityRecordSystem.toResourceId(),
        entityRecordOnlyAdminForCharactersOtherwiseAlsoOwnerSelectors[i],
        true
      );
    }
  }

  // Configure access for SmartAssemblySystem
  function configureSmartAssemblyAccess() public {
    bytes4[3] memory smartAssemblyOnlyAdminSelectors = [
      SmartAssemblySystem.createAssembly.selector,
      SmartAssemblySystem.setAssemblyType.selector,
      SmartAssemblySystem.updateAssemblyType.selector
    ];

    for (uint256 i = 0; i < smartAssemblyOnlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartAssemblySystem.toResourceId(),
        smartAssemblyOnlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(
        smartAssemblySystem.toResourceId(), 
        smartAssemblyOnlyAdminSelectors[i], 
        true
      );
    }
  }

  // Configure access for OwnershipSystem
  function configureOwnershipAccess() public {
    bytes4[5] memory ownershipOnlyAdminOrCallAccessWithScopeEnforcedSelectors = [
      OwnershipSystem.ascribeToAccount.selector,
      OwnershipSystem.ascribeToInventory.selector,
      OwnershipSystem.annulFromAccount.selector,
      OwnershipSystem.annulFromInventory.selector,
      OwnershipSystem.transferInventory.selector
    ];

    for (uint256 i = 0; i < ownershipOnlyAdminOrCallAccessWithScopeEnforcedSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ownershipSystem.toResourceId(),
        ownershipOnlyAdminOrCallAccessWithScopeEnforcedSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrCallAccessWithScopeEnforced.selector
      );
      accessConfigSystem.setAccessEnforcement(ownershipSystem.toResourceId(), ownershipOnlyAdminOrCallAccessWithScopeEnforcedSelectors[i], true);
    }
  }

  // Configure access for SmartCharacterSystem
  function configureSmartCharacterAccess() public {
    bytes4[3] memory onlyAdminSelectors = [
      SmartCharacterSystem.updateTribeId.selector,
      SmartCharacterSystem.createCharacter.selector,
      SmartCharacterSystem.removeCharacter.selector
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
    bytes4[4] memory fuelOnlyAdminSelectors = [
      FuelSystem.configureFuelParameters.selector,
      FuelSystem.setFuelUnitVolume.selector,
      FuelSystem.setFuelConsumptionIntervalInSeconds.selector,
      FuelSystem.setFuelMaxCapacity.selector
    ];

    for (uint256 i = 0; i < fuelOnlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        fuelSystem.toResourceId(),
        fuelOnlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), fuelOnlyAdminSelectors[i], true);
    }

    accessConfigSystem.configureAccess(
      fuelSystem.toResourceId(),
      FuelSystem.setFuelAmount.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrCallAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), FuelSystem.setFuelAmount.selector, true);

    accessConfigSystem.configureAccess(
      fuelSystem.toResourceId(),
      FuelSystem.updateFuel.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdminOrCallAccess.selector
    );
    accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), FuelSystem.updateFuel.selector, true);

    accessConfigSystem.configureAccess(
      fuelSystem.toResourceId(),
      FuelSystem.depositFuel.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(fuelSystem.toResourceId(), FuelSystem.depositFuel.selector, true);
  }

  // Configure access for DeployableSystem
  function configureDeployableAccess() public {
    bytes4[7] memory deployableOnlyAdminSelectors = [
      DeployableSystem.createAndAnchor.selector,
      DeployableSystem.createDeployable.selector,
      DeployableSystem.destroyDeployable.selector,
      DeployableSystem.anchor.selector,
      DeployableSystem.unanchor.selector,
      DeployableSystem.globalPause.selector,
      DeployableSystem.globalResume.selector
    ];

    for (uint256 i = 0; i < deployableOnlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        deployableSystem.toResourceId(),
        deployableOnlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(deployableSystem.toResourceId(), deployableOnlyAdminSelectors[i], true);
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
    bytes4[2] memory inventoryOnlyAdminSelectors = [
      InventorySystem.setCapacity.selector,
      InventorySystem.setEphemeralCapacity.selector
    ];

    for (uint256 i = 0; i < inventoryOnlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        inventoryOnlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(
        inventorySystem.toResourceId(), 
        inventoryOnlyAdminSelectors[i], 
        true
      );
    }

    bytes4[3] memory inventoryOnlyOwnerOrCallAccessSelectors = [
      InventorySystem.createAndDepositInventory.selector,
      InventorySystem.depositInventory.selector,
      InventorySystem.withdrawInventory.selector
    ];

    for (uint256 i = 0; i < inventoryOnlyOwnerOrCallAccessSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        inventorySystem.toResourceId(),
        inventoryOnlyOwnerOrCallAccessSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwnerOrCallAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(
        inventorySystem.toResourceId(), 
        inventoryOnlyOwnerOrCallAccessSelectors[i], 
        true
      );
    }
  }

  // Configure access for EphemeralInventorySystem
  function configureEphemeralInventoryAccess() public {
    bytes4[1] memory ephemeralInventoryOnlyAdminSelectors = [
      EphemeralInventorySystem.createAndDepositEphemeral.selector
    ];

    for (uint256 i = 0; i < ephemeralInventoryOnlyAdminSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryOnlyAdminSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdmin.selector
      );
      accessConfigSystem.setAccessEnforcement(ephemeralInventorySystem.toResourceId(), ephemeralInventoryOnlyAdminSelectors[i], true);
    }

    bytes4[2] memory ephemeralInventoryOnlyAdminOrCallAccessSelectors = [
      EphemeralInventorySystem.depositEphemeral.selector,
      EphemeralInventorySystem.withdrawEphemeral.selector
    ];

    for (uint256 i = 0; i < ephemeralInventoryOnlyAdminOrCallAccessSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryOnlyAdminOrCallAccessSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyAdminOrCallAccess.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInventorySystem.toResourceId(),
        ephemeralInventoryOnlyAdminOrCallAccessSelectors[i],
        true
      );
    }
  }

  // Configure access for EphemralInteractSystem
  function configureEphemeralInteractAccess() public {
    bytes4[1] memory ephemeralInteractOnlyOwnerOrCanTransferToEphemeralSelectors = [
      EphemeralInteractSystem.transferToEphemeral.selector
    ];
    for (uint256 i = 0; i < ephemeralInteractOnlyOwnerOrCanTransferToEphemeralSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerOrCanTransferToEphemeralSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwnerOrCanTransferToEphemeralRole.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerOrCanTransferToEphemeralSelectors[i],
        true
      );
    }

    bytes4[1] memory ephemeralInteractOnlyOwnerOrCanTransferFromEphemeralSelectors = [
      EphemeralInteractSystem.transferFromEphemeral.selector
    ];
    for (uint256 i = 0; i < ephemeralInteractOnlyOwnerOrCanTransferFromEphemeralSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerOrCanTransferFromEphemeralSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwnerOrCanTransferFromEphemeralRole.selector
      );
      accessConfigSystem.setAccessEnforcement(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerOrCanTransferFromEphemeralSelectors[i],
        true
      );
    }

    bytes4[2] memory ephemeralInteractOnlyOwnerSelectors = [
      EphemeralInteractSystem.setTransferFromEphemeralAccess.selector,
      EphemeralInteractSystem.setTransferToEphemeralAccess.selector
    ];
    for (uint256 i = 0; i < ephemeralInteractOnlyOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        ephemeralInteractSystem.toResourceId(),
        ephemeralInteractOnlyOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwner.selector
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
      AccessSystem.onlyOwnerOrCanTransferToInventoryRole.selector
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
      AccessSystem.onlyOwner.selector
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
      AccessSystem.onlyAdmin.selector
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
      AccessSystem.onlyAdmin.selector
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
    accessConfigSystem.configureAccess(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorGate.selector,
      accessSystem.toResourceId(),
      AccessSystem.onlyAdmin.selector
    );
    accessConfigSystem.setAccessEnforcement(
      smartGateSystem.toResourceId(),
      SmartGateSystem.createAndAnchorGate.selector,
      true
    );

    bytes4[3] memory smartGateOnlyOwnerSelectors = [
      SmartGateSystem.configureGate.selector,
      SmartGateSystem.linkGates.selector,
      SmartGateSystem.unlinkGates.selector
    ];

    for (uint256 i = 0; i < smartGateOnlyOwnerSelectors.length; i++) {
      accessConfigSystem.configureAccess(
        smartGateSystem.toResourceId(),
        smartGateOnlyOwnerSelectors[i],
        accessSystem.toResourceId(),
        AccessSystem.onlyOwner.selector
      );
      accessConfigSystem.setAccessEnforcement(smartGateSystem.toResourceId(), smartGateOnlyOwnerSelectors[i], true);
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
    entitySystem.scopedRegisterClass(classId, _callMsgSender(1), systemIds);

    return classId;
  }
}
