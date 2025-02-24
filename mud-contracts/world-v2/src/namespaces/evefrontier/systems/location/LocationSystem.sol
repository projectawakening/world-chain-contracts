// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";
import { Location, LocationData } from "../../codegen/index.sol";

/**
 * @title LocationSystem
 * @author CCP Games
 * LocationSystem stores the location of a smart object on-chain
 */
contract LocationSystem is SmartObjectFramework {
  /**
   * @dev saves the location data of the in-game object
   * @param smartObjectId smartObjectId of the in-game object
   * @param locationData the location data of the location
   */
  function saveLocation(
    uint256 smartObjectId,
    LocationData memory locationData
  ) public context access(smartObjectId) scope(smartObjectId) {
    Location.set(smartObjectId, locationData);
  }
}
