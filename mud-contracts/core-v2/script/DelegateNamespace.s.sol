// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { NamespaceOwner } from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import { RESOURCE_NAMESPACE, RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { requireNamespace } from "@latticexyz/world/src/requireNamespace.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { AccessControl } from "@latticexyz/world/src/AccessControl.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { DelegationControlSystem } from "../src/systems/DelegationControlSystem.sol";

contract DelegateNamespace is Script {
   bytes14 constant DEPLOYMENT_NAMESPACE = "evefrontier";
  function run(address worldAddress) external {
    StoreSwitch.setStoreAddress(worldAddress);
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address delegatee = vm.envAddress("FORWARDER_ADDRESS");
    string memory erc20NamespaceString = vm.envString("EVE_TOKEN_NAMESPACE"); 
   
    bytes14 erc20Namespace = stringToBytes14(erc20NamespaceString);

    ResourceId WORLD_NAMESPACE_ID = ResourceId.wrap(
      bytes32(abi.encodePacked(RESOURCE_NAMESPACE, DEPLOYMENT_NAMESPACE))
    );
    ResourceId ERC20_NAMESPACE_ID = ResourceId.wrap(bytes32(abi.encodePacked(RESOURCE_NAMESPACE, erc20Namespace)));

    vm.startBroadcast(deployerPrivateKey);
    requireNamespace(WORLD_NAMESPACE_ID);
    requireNamespace(ERC20_NAMESPACE_ID);
    console.log(NamespaceOwner.get(WORLD_NAMESPACE_ID));
    console.log(NamespaceOwner.get(ERC20_NAMESPACE_ID));

    DelegationControlSystem delegationControl = new DelegationControlSystem();
    ResourceId delegationControlId = delegationControlSystemId();

    IWorld(worldAddress).registerSystem(delegationControlId, delegationControl, true);

    //Delegate the World namespace to the delegatee (Forwarder contract)
    IWorld(worldAddress).registerNamespaceDelegation(
      WORLD_NAMESPACE_ID,
      delegationControlId,
      abi.encodeWithSelector(delegationControl.initDelegation.selector, WORLD_NAMESPACE_ID, delegatee)
    );
    console.log(AccessControl.hasAccess(WORLD_NAMESPACE_ID, delegatee));

    //Delegate the ERC20 namespace to the delegatee (Forwarder contract)
    IWorld(worldAddress).registerNamespaceDelegation(
      ERC20_NAMESPACE_ID,
      delegationControlId,
      abi.encodeWithSelector(delegationControl.initDelegation.selector, ERC20_NAMESPACE_ID, delegatee)
    );

    vm.stopBroadcast();
  }

  function delegationControlSystemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: DEPLOYMENT_NAMESPACE, name: "DelegationContr" });
  }

  function stringToBytes14(string memory str) public pure returns (bytes14) {
    bytes memory tempBytes = bytes(str);

    // Ensure the bytes array is not longer than 14 bytes.
    // If it is, this will truncate the array to the first 14 bytes.
    // If it's shorter, it will be padded with zeros.
    require(tempBytes.length <= 14, "String too long");

    bytes14 converted;
    for (uint i = 0; i < tempBytes.length; i++) {
      converted |= bytes14(tempBytes[i] & 0xFF) >> (i * 8);
    }

    return converted;
  }
}
