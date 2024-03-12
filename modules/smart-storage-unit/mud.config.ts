import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "ssu", //having a short namespace as the MUD Namespace must be <= 14 characters
  systems: {
    SmartStorageUnit: {
      name: "SmartStorageUnit",
      openAccess: true,
    },
  },
  enums: {
    State: ["ANCHOR", "UNANCHOR", "ONLINE", "OFFLINE", "DESTROYED"],
  },
  tables: {
    /**
     * Used to store the metadata of a in-game entity
     * Singleton entityId is the hash of (typeId, itemId and databaseId) ?
     * Non Singleton entityId is the hash of the typeId 
     */
    EntityRecord: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        itemId: "uint256",
        typeId: "uint256",
        volume: "uint256",
      },
    },
    /**
     * Used to store the location of a in-game entity in the solar system
     */
    Location: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        solarsystemId: "uint256",
        x: "uint256",
        y: "uint256",
        z: "uint256",
      },
    },
    /**
     * Used to store the current state of a deployable
     */
    DeployableState: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        createdAt: "uint256",
        state: "State",
        updatedBlockNumber: "uint256",
      },
    },
    /**
     * Used to store the DNS which servers the IPFS gateway
     */
    StaticDataGlobal: {
      valueSchema: {
        baseURI: "bytes32",
      },
    },
    /**
     * Used to store the IPFS CID of a smart object 
     */
    StaticData: {
      keySchema: {
        smartObjectId: "uint256",
      },
      valueSchema: {
        cid: "bytes32",
      },
    },
  },
});
