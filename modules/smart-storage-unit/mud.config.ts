import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
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
    StaticDataGlobal: {
      valueSchema: {
        baseURI: "bytes32",
      },
    },
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
