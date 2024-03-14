import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  namespace: "EntityRecor_v0",
  excludeSystems: ["EveSystem"],
  tables: {
    EntityRecordTable: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        isSingleton: "bool",
        itemId: "uint256",
        typeId: "uint256",
        volume: "uint256",
      },
      tableIdArgument: true,
    },
    EntityRecordOffchain: {
      keySchema: {
        entityId: "uint256",
      }, 
      valueSchema: {
        name: "string",
        dappURL: "string",
        description: "string",
      }
    }
  },
});