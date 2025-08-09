// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

//import { worldRegistrationSystem } from "@latticexyz/world/src/codegen/experimental/systems/WorldRegistrationSystemLib.sol";
//import { moduleInstallationSystem } from "@latticexyz/world/src/codegen/experimental/systems/ModuleInstallationSystemLib.sol";
import { UNLIMITED_DELEGATION } from "@latticexyz/world/src/constants.sol";

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";

import { AccessConfigSystem } from "../namespaces/evefrontier/codegen/systems/AccessConfigSystemLib.sol";
import { CallAccessSystem } from "../namespaces/evefrontier/codegen/systems/CallAccessSystemLib.sol";
import { EntitySystem } from "../namespaces/evefrontier/codegen/systems/EntitySystemLib.sol";
import { RoleManagementSystem } from "../namespaces/evefrontier/codegen/systems/RoleManagementSystemLib.sol";
import { TagSystem } from "../namespaces/evefrontier/codegen/systems/TagSystemLib.sol";
import { SOFAccessSystem } from "../namespaces/sofaccess/codegen/systems/SOFAccessSystemLib.sol";

import { SOFModule } from "./SOFModule.sol";

function delegateInstallSOFModule() {
  delegateInstallSOFModule(
    new SOFModule(
      new AccessConfigSystem(),
      new CallAccessSystem(),
      new EntitySystem(),
      new RoleManagementSystem(),
      new TagSystem(),
      new SOFAccessSystem()
    )
  );
}

/**
 * @notice Deploys the SOF module, and installs it via delegation.
 * The module installation atomically registers the SOF tables and systems, and configues their access.
 */
function delegateInstallSOFModule(
  SOFModule module
) {
  IBaseWorld world = IBaseWorld(WorldContextConsumerLib._world());

  world.registerDelegation(address(module), UNLIMITED_DELEGATION, "");
  world.installModule(module, "");
  world.unregisterDelegation(address(module));
}