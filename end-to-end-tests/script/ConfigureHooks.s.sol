// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { IAccessControlSystem } from "@eveworld/world-core/src/codegen/world/IAccessControlSystem.sol";
import { AccessControlSystem } from "@eveworld/world-core/src/systems/access-control/AccessControlSystem.sol";
import { Utils as AccessControlUtils } from "@eveworld/world-core/src/systems/access-control/Utils.sol";
import { Role } from "@eveworld/world-core/src/codegen/tables/Role.sol";

import { ISmartStorageUnit } from "@eveworld/world/src/modules/smart-storage-unit/interfaces/ISmartStorageUnit.sol";
import { ISmartCharacter } from "@eveworld/world/src/modules/smart-character/interfaces/ISmartCharacter.sol";
import { Utils as SmartCharacterUtils } from "@eveworld/world/src/modules/smart-character/Utils.sol";
import { Utils as SmartStorageUnitUtils } from "@eveworld/world/src/modules/smart-storage-unit/Utils.sol";

import { HookTable } from "@eveworld/smart-object-framework/src/codegen/tables/HookTable.sol";
import { SmartObjectLib } from "@eveworld/smart-object-framework/src/SmartObjectLib.sol";
import { HOOK_SYSTEM_ID, HOOK_SYSTEM_NAME, OBJECT, CLASS } from "@eveworld/smart-object-framework/test/constants.sol";
import { Utils } from "@eveworld/smart-object-framework/src/Utils.sol";
import { HookType } from "@eveworld/smart-object-framework/src/types.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

contract ConfigureHooks is Script {
  using Utils for bytes14;
  using SmartStorageUnitUtils for bytes14;
  using AccessControlUtils for bytes14;
  using SmartCharacterUtils for bytes14;
  using SmartObjectLib for SmartObjectLib.World;

  SmartObjectLib.World smartObjectFramework;

  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 playerPrivateKey = vm.envUint("PRIVATE_KEY");
    //TODO make the classId configurable

    vm.startBroadcast(playerPrivateKey);

    // Get the admin role
    address admin = Role.get("ADMIN");
    console.log("Admin: ", admin);

    //Register Hook
    smartObjectFramework = SmartObjectLib.World({
      iface: IBaseWorld(worldAddress),
      namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE
    });

    //Register Hook onlyAdmin
    bytes4 onlyAdminHookFunctionId = IAccessControlSystem.onlyAdminHook.selector;
    smartObjectFramework.registerHook(AccessControlUtils.accessControlSystemId(), onlyAdminHookFunctionId);

    uint256 onlyAdminHookId = uint256(
      keccak256(abi.encodePacked(AccessControlUtils.accessControlSystemId(), onlyAdminHookFunctionId))
    );
    console.log("Only Admin Hook ID: ", onlyAdminHookId);

    //Register hook for onlyOwner
    bytes4 onlyOwnerHookFunctionId = IAccessControlSystem.onlyOwnerHook.selector;

    smartObjectFramework.registerHook(AccessControlUtils.accessControlSystemId(), onlyOwnerHookFunctionId);

    uint256 onlyOwnerHookId = uint256(
      keccak256(abi.encodePacked(AccessControlUtils.accessControlSystemId(), onlyOwnerHookFunctionId))
    );
    console.log("Only Owner Hook ID: ", onlyOwnerHookId);

    //Add hook for createCharacter
    _addHookForCreateSmartCharacter(smartObjectFramework, onlyAdminHookId);
    _addHookForCreateAndAnchor(smartObjectFramework, onlyAdminHookId);

    uint256 targetid = uint256(
      keccak256(
        abi.encodePacked(
          FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
          ISmartCharacter.createCharacter.selector
        )
      )
    );

    vm.stopBroadcast();
  }

  function _addHookForCreateSmartCharacter(SmartObjectLib.World memory smartObjectFramework, uint256 hookId) internal {
    uint256 smartCharacterClassId = uint256(keccak256("SmartCharacterClass"));
    //asscoaite hook with a entity
    smartObjectFramework.associateHook(smartCharacterClassId, hookId);

    //Add hook for createCharacter
    smartObjectFramework.addHook(
      hookId,
      HookType.AFTER,
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartCharacterSystemId(),
      ISmartCharacter.createCharacter.selector
    );
  }

  function _addHookForCreateAndAnchor(SmartObjectLib.World memory smartObjectFramework, uint256 hookId) internal {
    uint256 ssuClassId = uint256(keccak256("SSUClass"));
    //asscoaite hook with a entity
    smartObjectFramework.associateHook(ssuClassId, hookId);

    //Add hook for createCharacter
    smartObjectFramework.addHook(
      hookId,
      HookType.AFTER,
      FRONTIER_WORLD_DEPLOYMENT_NAMESPACE.smartStorageUnitSystemId(),
      ISmartStorageUnit.createAndAnchorSmartStorageUnit.selector
    );
  }
}
