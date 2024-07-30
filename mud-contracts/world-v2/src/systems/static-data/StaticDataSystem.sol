// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

import { System } from "@latticexyz/world/src/System.sol";
import { StaticData, StaticDataMetadata } from "../../codegen/index.sol";

/**
 * @title EntityRecordSystem
 * @author CCP Games
 * EntityRecordSystem stores an in game entity record on chain.
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
   * @dev creates a new static data entry
   * @param systemId systemId of the in-game object
   * @param name name of the in-game object
   * @param symbol URL of the dapp
   * @param baseURI baseURI of the in-game object
   */
  function createStaticDataMetadata(
    ResourceId systemId,
    string memory name,
    string memory symbol,
    string memory baseURI
  ) public {
    StaticDataMetadata.set(systemId, name, symbol, baseURI);
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
   * @dev updates the cid of the in-game object
   * @param systemId systemId of the in-game object
   * @param name name of the in-game object
   */
  function setName(ResourceId systemId, string memory name) public {
    StaticDataMetadata.setName(systemId, name);
  }

  /**
   * @dev updates the cid of the in-game object
   * @param systemId systemId of the in-game object
   * @param symbol symbol of the in-game object
   */
  function setSymbol(ResourceId systemId, string memory symbol) public {
    StaticDataMetadata.setSymbol(systemId, symbol);
  }
  /**
   * @dev updates the cid of the in-game object
   * @param systemId systemId of the in-game object
   * @param baseURI the baseURI of the static data
   */
  function setBaseURI(ResourceId systemId, string memory baseURI) public {
    StaticDataMetadata.setBaseURI(systemId, baseURI);
  }
}
