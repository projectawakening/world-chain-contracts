
import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "StaticData_v0",
  excludeSystems: ["EveSystem"],
  tables: {
    StaticDataGlobal: {
      
      valueSchema: {
        createdAt: "uint256",
        name: "string",
      },
      storeArgument: true,
      tableIdArgument: true,
    },
  },
});