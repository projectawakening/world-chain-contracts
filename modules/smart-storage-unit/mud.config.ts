import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  systems: {
    SmartStorageUnit: {
      name: "SmartStorageUnit",
      openAccess: true,
    },
  },
  tables: {
    SmartStorageUnits: {
      valueSchema: {
        createdAt: "uint256",
        name: "string",
        description: "string",
      },
    },
  },
});
