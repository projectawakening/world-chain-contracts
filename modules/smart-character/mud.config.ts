import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
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
        createdAt: "uint256",
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
