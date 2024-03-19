import { mudConfig } from "@latticexyz/world/register";

export default mudConfig({
  systems: {
    SmartCharacterSystem: {
      name: "SmartCharacterSystem",
      openAccess: true,
    },
  },
  tables: {
    /**
     * Maps the in-game character ID to on-chain EOA address
     */
    Characters: {
      keySchema: {
        characterId: "uint256",
      },
      valueSchema: {
        characterAddress: "address",
        createdAt: "uint256",
      },
    },
  },
});
