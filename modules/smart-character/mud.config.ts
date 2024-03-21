import { mudConfig } from "@latticexyz/world/register";
import constants from "@eve/common-constants/src/constants.json" assert { type: "json" };

export default mudConfig({
  namespace: constants.SMART_CHARACTER_DEPLOYMENT_NAMESPACE,
  systems: {
    SmartCharacter: {
      name: "SmartCharacter",
      openAccess: true,
    },
  },
  tables: {
    /**
     * Maps the in-game character ID to on-chain EOA address
     */
    CharactersTable: {
      keySchema: {
        characterId: "uint256",
      },
      valueSchema: {
        characterAddress: "address",
        createdAt: "uint256"
      },
      tableIdArgument: true,
    },
    
    CharactersConstantsTable: {
      keySchema: {},
      valueSchema: {
        erc721Address: "address",
      },
      tableIdArgument: true,
    },
  },
});