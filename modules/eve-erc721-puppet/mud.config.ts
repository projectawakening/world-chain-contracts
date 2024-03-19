import { mudConfig } from "@latticexyz/world/register";
// since mud doesnt use that sub-repo's tsconfig.json, this works
import constants from "@eve/common-constants/src/constants.json" assert { type: "json" };

export default mudConfig({
  namespace: constants.EVE_ERC721_PUPPET_DEPLOYMENT_NAMESPACE,

  excludeSystems: ["EveSystem"],
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", internalType: "bytes32" },
  },
  tables: {
    Balances: {
      keySchema: {
        account: "address",
      },
      valueSchema: {
        value: "uint256",
      },
      tableIdArgument: true,
    },
    ERC721Metadata: {
      keySchema: {},
      valueSchema: {
        name: "string",
        symbol: "string",
        baseURI: "string",
      },
      tableIdArgument: true,
    },
    TokenURI: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        tokenURI: "string",
      },
      tableIdArgument: true,
    },
    Owners: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        owner: "address",
      },
      tableIdArgument: true,
    },
    ERC721Registry: {
      keySchema: {
        namespaceId: "ResourceId",
      },
      valueSchema: {
        tokenAddress: "address",
      },
      tableIdArgument: true,
    },
    TokenApproval: {
      keySchema: {
        tokenId: "uint256",
      },
      valueSchema: {
        account: "address",
      },
      tableIdArgument: true,
    },
    OperatorApproval: {
      keySchema: {
        owner: "address",
        operator: "address",
      },
      valueSchema: {
        approved: "bool",
      },
      tableIdArgument: true,
    },
  },
});