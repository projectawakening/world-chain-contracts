//SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * EntityRecord system stores an in game entity record on chain.
 * @param entityId the id of a in game entity referred as smart object id
 * @param typeId the typeId of the in-game entity
 * @param itemId the itemId of the in-game entity
 * @param volume the volume of the in-game entity
 */
struct EntityRecordData {
  uint256 entityId;
  uint256 typeId;
  uint256 itemId;
  uint256 volume;
}

/**
 * EntityMetadata system stores the metadata of an in game entity record on chain.
 * @param entityId the id of a in game entity referred as smart object id
 * @param name the name of the entity
 * @param dappURL stores the URL where the dapp for an entity is hosted
 * @param description the description of the entity
 */
struct EntityMetadata {
  uint256 entityId;
  string name;
  string dappURL;
  string description;
}
