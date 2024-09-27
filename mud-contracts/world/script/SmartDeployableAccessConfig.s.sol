pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";

import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE as WORLD_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { Utils as AccessUtils } from "../src/modules/access/Utils.sol";
import { Utils } from "../src/modules/smart-deployable/Utils.sol";

import { IAccessSystem } from "../src/modules/access/interfaces/IAccessSystem.sol";
import { ISmartDeployableSystem } from "../src/modules/smart-deployable/interfaces/ISmartDeployableSystem.sol";

contract SmartDeployableAccessConfig is Script {
  using AccessUtils for bytes14;
  using Utils for bytes14;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    
    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);
    IBaseWorld world = IBaseWorld(worldAddress);
    {
      // SmartDeployableSystem
      // SmartDeployable.registerDeployable
      bytes32 register = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.registerDeployable.selector));
      // SmartDeployable.setSmartAssemblyType
      bytes32 setType = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.setSmartAssemblyType.selector));
      // SmartDeployable.destroyDeployable
      bytes32 destroy = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.destroyDeployable.selector));
      // SmartDeployable.bringOnline
      bytes32 online = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.bringOnline.selector));
      // SmartDeployable.bringOffline
      bytes32 offline = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.bringOffline.selector));
      // SmartDeployable.anchor
      bytes32 anchor = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.anchor.selector));
      // SmartDeployable.unanchor
      bytes32 unanchor = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.unanchor.selector));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (register, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setType, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (destroy, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (online, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (offline, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (anchor, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (unanchor, true)));
    }
    {
      // SmartDeployable.globalPause
      bytes32 pause = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.globalPause.selector));
      // SmartDeployable.globalResume
      bytes32 resume = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.globalResume.selector));
      // SmartDeployable.setFuelConsumptionPerMinute
      bytes32 setFuel = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.setFuelConsumptionPerMinute.selector));
      // SmartDeployable.setFuelMaxCapacity
      bytes32 setMax = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.setFuelMaxCapacity.selector));
      // SmartDeployable.depositFuel
      bytes32 deposit = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.depositFuel.selector));
      // SmartDeployable.withdrawFuel
      bytes32 withdraw = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.withdrawFuel.selector));
      // SmartDeployable.registerDeployableToken
      bytes32 tokenReg = keccak256(abi.encodePacked(WORLD_NAMESPACE.smartDeployableSystemId(), ISmartDeployableSystem.registerDeployableToken.selector));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (pause, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (resume, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setFuel, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (setMax, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (deposit, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (withdraw, true)));
      world.call(WORLD_NAMESPACE.accessSystemId(), abi.encodeCall(IAccessSystem.setAccessEnforcement, (tokenReg, true)));
    }

    vm.stopBroadcast();

  }
}