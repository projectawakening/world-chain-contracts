import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  tables: {
    Characters: {
      valueSchema: {
        createdAt: "uint256",
        name: "string",
      },
    },
  },
});
