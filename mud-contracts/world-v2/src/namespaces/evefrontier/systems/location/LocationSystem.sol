// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
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

  /**
   * @dev updates the solar system id of the in-game object
   * @param smartObjectId smartObjectId of the in-game object
   * @param solarSystemId the solarSystemId of the location
   */
  function setSolarSystemId(
    uint256 smartObjectId,
    uint256 solarSystemId
  ) public context access(smartObjectId) scope(smartObjectId) {
    Location.setSolarSystemId(smartObjectId, solarSystemId);
  }

  /**
   * @dev updates the x coordinate of the in-game object
   * @param smartObjectId smartObjectId of the in-game object
   * @param x x coordinate of the location
   */
  function setX(uint256 smartObjectId, uint256 x) public context access(smartObjectId) scope(smartObjectId) {
    Location.setX(smartObjectId, x);
  }

  /**
   * @dev updates the y coordinate of the in-game object
   * @param smartObjectId smartObjectId of the in-game object
   * @param y y coordinate of the location
   */
  function setY(uint256 smartObjectId, uint256 y) public context access(smartObjectId) scope(smartObjectId) {
    Location.setY(smartObjectId, y);
  }

  /**
   * @dev updates the z coordinate of the in-game object
   * @param smartObjectId smartObjectId of the in-game object
   * @param z z coordinate of the location
   */

  function setZ(uint256 smartObjectId, uint256 z) public context access(smartObjectId) scope(smartObjectId) {
    Location.setZ(smartObjectId, z);
  }
}
