import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  tables: {
    GlobalStaticData: {
      keySchema: {
        trustedForwarder: "address",
      },
      valueSchema: "bool",
    }
  },
});
