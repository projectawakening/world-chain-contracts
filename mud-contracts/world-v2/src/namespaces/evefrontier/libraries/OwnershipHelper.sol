// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IWorldCall } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { OwnershipSystem, ownershipSystem } from "../codegen/systems/OwnershipSystemLib.sol";

import { IWorldWithContext } from "@eveworld/smart-object-framework-v2/src/IWorldWithContext.sol";

library OwnershipHelper {
  function getOwner(uint256 smartObjectId) internal view returns (address) {
    bytes memory returnData = world().callStatic(
      ownershipSystem.toResourceId(),
      abi.encodeCall(OwnershipSystem.owner, (smartObjectId))
    );
    return abi.decode(returnData, (address));
  }

  function world() internal view returns (IWorldWithContext) {
    return IWorldWithContext(StoreSwitch.getStoreAddress());
  }
}
