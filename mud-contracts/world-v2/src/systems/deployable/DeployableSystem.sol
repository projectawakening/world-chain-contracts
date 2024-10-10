// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { GlobalDeployableState, GlobalDeployableStateData } from "../../codegen/index.sol";
import { DeployableState, DeployableStateData } from "../../codegen/index.sol";
import { DeployableTokenTable } from "../../codegen/index.sol";
import { FuelSystem } from "../fuel/FuelSystem.sol";
import { Fuel, FuelData } from "../../codegen/index.sol";
import { LocationSystem } from "../location/LocationSystem.sol";
import { LocationData } from "../../codegen/tables/Location.sol";
import { Location, LocationData } from "../../codegen/index.sol";
import { IERC721Mintable } from "../eve-erc721-puppet/IERC721Mintable.sol";
import { StaticDataSystem } from "../static-data/StaticDataSystem.sol";
import { EveSystem } from "../EveSystem.sol";

import { State, SmartObjectData } from "./types.sol";
import { DECIMALS, ONE_UNIT_IN_WEI } from "./constants.sol";

import { LocationUtils } from "../location/LocationUtils.sol";
import { StaticDataUtils } from "../static-data/StaticDataUtils.sol";
import { EntityRecordUtils } from "../entity-record/EntityRecordUtils.sol";

/**
 * @title DeployableSystem
 * @author CCP Games
 * DeployableSystem stores the deployable state of a smart object on-chain
 */
contract DeployableSystem is EveSystem {
  error SmartDeployable_IncorrectState(uint256 entityId, State currentState);
  error SmartDeployable_NoFuel(uint256 entityId);
  error SmartDeployable_StateTransitionPaused();
  error SmartDeployable_TooMuchFuelDeposited(uint256 entityId, uint256 amountDeposited);
  error SmartDeployableERC721AlreadyInitialized();
  error SmartDeployable_InvalidFuelConsumptionInterval(uint256 entityId);

  using LocationUtils for bytes14;
  using StaticDataUtils for bytes14;

  /**
   * modifier to enforce deployable state changes can happen only when the game server is running
   */
  modifier onlyActive() {
    if (GlobalDeployableState.getIsPaused() == false) {
      revert SmartDeployable_StateTransitionPaused();
    }
    _;
  }
}
