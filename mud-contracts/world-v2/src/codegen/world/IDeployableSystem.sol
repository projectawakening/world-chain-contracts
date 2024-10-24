// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { State, SmartObjectData } from "../../systems/deployable/types.sol";
import { EntityRecordData } from "../../systems/entity-record/types.sol";
import { LocationData } from "../index.sol";

/**
 * @title IDeployableSystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IDeployableSystem {
  error Deployable_IncorrectState(uint256 smartObjectId, State currentState);
  error Deployable_NoFuel(uint256 smartObjectId);
  error Deployable_StateTransitionPaused();
  error Deployable_TooMuchFuelDeposited(uint256 smartObjectId, uint256 amountDeposited);
  error DeployableERC721AlreadyInitialized();
  error Deployable_InvalidFuelConsumptionInterval(uint256 smartObjectId);
  error Deployable_InvalidObjectOwner(string message, address smartObjectOwner, uint256 smartObjectId);

  function evefrontier__createAndAnchorDeployable(
    uint256 smartObjectId,
    string memory smartAssemblyType,
    EntityRecordData memory entityRecordData,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity,
    LocationData memory locationData
  ) external;

  function evefrontier__registerDeployableToken(address erc721Address) external;

  function evefrontier__registerDeployable(
    uint256 smartObjectId,
    SmartObjectData memory smartObjectData,
    uint256 fuelUnitVolume,
    uint256 fuelConsumptionIntervalInSeconds,
    uint256 fuelMaxCapacity
  ) external;

  function evefrontier__destroyDeployable(uint256 smartObjectId) external;

  function evefrontier__bringOnline(uint256 smartObjectId) external;

  function evefrontier__bringOffline(uint256 smartObjectId) external;

  function evefrontier__anchor(uint256 smartObjectId, LocationData memory locationData) external;

  function evefrontier__unanchor(uint256 smartObjectId) external;

  function evefrontier__globalPause() external;

  function evefrontier__globalResume() external;
}
