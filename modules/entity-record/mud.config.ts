import { mudConfig } from "@latticexyz/world/register";
// since mud doesnt use that sub-repo's tsconfig.json, this works
import constants from "@eve/common-constants/src/constants.json" assert { type: "json" };

export default mudConfig({
  namespace: constants.ENTITY_RECORD_DEPLOYMENT_NAMESPACE,

  excludeSystems: ["EveSystem"],
  tables: {
    EntityRecordTable: {
      keySchema: {
        entityId: "uint256",
      },
      valueSchema: {
        itemId: "uint256",
        typeId: "uint8",
        volume: "uint256",
      },
      tableIdArgument: true,
    },
    EntityRecordOffchainTable: {
      keySchema: {
        entityId: "uint256",
      }, 
      valueSchema: {
        name: "string",
        dappURL: "string",
        description: "string",
      },
      tableIdArgument: true,
    }
  },
});