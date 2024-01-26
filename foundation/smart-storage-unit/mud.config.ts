import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
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
