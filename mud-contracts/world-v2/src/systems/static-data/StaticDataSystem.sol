// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { StaticData, StaticDataMetadata } from "../../codegen/index.sol";

/**
 * @title StaticData
 * @author CCP Games
 * StaticDataSystem stores an in game entity record on chain.
 */
contract StaticDataSystem is System {
  /**
   * @dev updates the cid of the in-game object
   * @param smartObjectId on-chain id of the in-game object
   * @param cid the content identifier of the static data
   */
  function setCid(uint256 smartObjectId, string memory cid) public {
    StaticData.set(smartObjectId, cid);
  }

  /**
   * @dev updates the baseURI of the in-game object
   * @param baseURI the baseURI of the static data
   */
  function setBaseURI(string memory baseURI) public {
    StaticDataMetadata.set(baseURI);
  }
}
