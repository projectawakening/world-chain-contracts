import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  tables: {
    GlobalStaticData: {
      keySchema: {
        trustedForwarder: "address",
      },
      valueSchema: "bool",
    },
    Role: {
      keySchema: {
        role: "bytes32",
      },
      valueSchema: "address",
    },
  },
});
