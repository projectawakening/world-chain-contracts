// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { SystemSwitch } from "@latticexyz/world-modules/src/utils/SystemSwitch.sol";

import { ERC721Module } from "./ERC721Module.sol";
import { MODULE_NAMESPACE_ID, ERC721_REGISTRY_TABLE_ID } from "./constants.sol";
import { IERC721Mintable } from "./IERC721Mintable.sol";
import { Utils } from "./Utils.sol";

import { ModulesInitializationLibrary } from "../../../src/utils/ModulesInitializationLibrary.sol";
import { SmartObjectLib } from "@eveworld/frontier-smart-object-framework/src/SmartObjectLib.sol";
import { OBJECT } from "@eveworld/frontier-smart-object-framework/src/constants.sol";
import { SMART_OBJECT_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { StaticDataGlobalTableData } from "../../codegen/tables/StaticDataGlobalTable.sol";
import { ERC721Registry } from "../../codegen/tables/ERC721Registry.sol";

/**
 * @notice Register a new ERC721 token with the given metadata in a given namespace
 * @dev This function must be called within a Store context (i.e. using StoreSwitch.setStoreAddress())
 */
function registerERC721(
  IBaseWorld world,
  bytes14 namespace,
  StaticDataGlobalTableData memory metadata
) returns (IERC721Mintable token) {
  // Get the ERC721 module
  ERC721Module erc721Module = ERC721Module(NamespaceOwner.get(MODULE_NAMESPACE_ID));
  if (address(erc721Module) == address(0)) {
    erc721Module = new ERC721Module();
  }
  SmartObjectLib.World memory iworld = SmartObjectLib.World(world, SMART_OBJECT_DEPLOYMENT_NAMESPACE);
  uint256 entityId = uint256(ResourceId.unwrap(Utils.erc721SystemId(namespace)));
  SmartObjectLib.registerEntity(iworld, entityId, OBJECT);
  ModulesInitializationLibrary.associateStaticData(world, entityId);

  // Install the ERC721 module with the provided args
  world.installModule(erc721Module, abi.encode(namespace, metadata));

  // Return the newly created ERC721 token
  token = IERC721Mintable(ERC721Registry.get(ERC721_REGISTRY_TABLE_ID, WorldResourceIdLib.encodeNamespace(namespace)));
}
