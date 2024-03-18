
import { mudConfig } from "@latticexyz/world/register";
// since mud doesnt use that sub-repo's tsconfig.json, this works
import constants from "@eve/common-constants/src/constants.json" assert { type: "json" };

export default mudConfig({
  namespace: constants.STATIC_DATA_DEPLOYMENT_NAMESPACE,
  excludeSystems: ["EveSystem"],
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", internalType: "bytes32" },
  },
  tables: {
    StaticDataTable: {
      keySchema: {
        key: "uint256",
      },
      valueSchema: {
        cid: "string",
      },
      tableIdArgument: true,
    },
    StaticDataGlobalTable: {
      keySchema: {
        systemId: "ResourceId",
      },
      valueSchema: {
        baseURI: "string",
      },
      tableIdArgument: true,
    },
  },
});