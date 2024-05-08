// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { validateNamespace } from "@latticexyz/world/src/validateNamespace.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { AccessControl } from "@latticexyz/world/src/AccessControl.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as DEPLOYMENT_NAMESPACE } from "@eve/common-constants/src/constants.sol";
import { IWorld } from "../src/codegen/world/IWorld.sol";
import { DelegationControlSystem } from "../src/systems/DelegationControlSystem.sol";

contract DelegateNamespace is Script {
  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address delegatee = vm.envAddress("FORWARDER_ADDRESS");

    ResourceId NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, DEPLOYMENT_NAMESPACE)));

    vm.startBroadcast(deployerPrivateKey);
    validateNamespace(NAMESPACE_ID);
    console.log(NamespaceOwner.get(NAMESPACE_ID));

    DelegationControlSystem delegationControl = new DelegationControlSystem();
    ResourceId delegationControlId = delegationControlSystemId();

    IWorld(worldAddress).registerSystem(delegationControlId, delegationControl, true);

    IWorld(worldAddress).registerNamespaceDelegation(
      NAMESPACE_ID,
      delegationControlId,
      abi.encodeWithSelector(delegationControl.initDelegation.selector, NAMESPACE_ID, delegatee)
    );
    console.log(AccessControl.hasAccess(NAMESPACE_ID, delegatee));

    vm.stopBroadcast();
  }

  function delegationControlSystemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: DEPLOYMENT_NAMESPACE, name: "DelegationContr" });
  }
}