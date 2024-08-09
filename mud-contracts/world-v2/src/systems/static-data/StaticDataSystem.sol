// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { StaticData, StaticDataMetadata } from "../../codegen/index.sol";

/**
 * @title StaticData
 * @author CCP Games
 * StaticDataS stores an in game entity record on chain.
 */
contract StaticDataSystem is System {
  /**
   * @dev creates a new static data entry
   * @param entityId entityId of the in-game object
   * @param cid the content identifier of the static data
   */
  function createStaticData(uint256 entityId, string memory cid) public {
    StaticData.set(entityId, cid);
  }

  /**
   * @dev Stores the metadata details about the IPFS gateway.
   * @param classId classId of the in-game object
   * @param name name of the in-game object
   * @param baseURI baseURI of the in-game object
   */
  function createStaticDataMetadata(bytes32 classId, string memory name, string memory baseURI) public {
    StaticDataMetadata.set(classId, name, baseURI);
  }

  /**
   * @dev updates the cid of the in-game object
   * @param entityId entityId of the in-game object
   * @param cid the content identifier of the static data
   */
  function setCid(uint256 entityId, string memory cid) public {
    StaticData.set(entityId, cid);
  }

  /**
   * @dev updates the name of the in-game object
   * @param classId classId of the in-game object
   * @param name name of the in-game object
   */
  function setName(bytes32 classId, string memory name) public {
    StaticDataMetadata.setName(classId, name);
  }

  /**
   * @dev updates the baseURI of the in-game object
   * @param classId classId of the in-game object
   * @param baseURI the baseURI of the static data
   */
  function setBaseURI(bytes32 classId, string memory baseURI) public {
    StaticDataMetadata.setBaseURI(classId, baseURI);
  }
}
