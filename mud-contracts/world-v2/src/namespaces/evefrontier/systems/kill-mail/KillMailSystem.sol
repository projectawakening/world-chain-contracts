// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

// Smart Object Framework imports
import { SmartObjectFramework } from "@eveworld/smart-object-framework-v2/src/inherit/SmartObjectFramework.sol";

// Local namespace tables
import { Characters, KillMail, KillMailData } from "../../codegen/index.sol";

// Types and parameters
import { KillMailLossType } from "../../../../codegen/common.sol";

/**
 * @title KillMailSystem
 * @author CCP Games
 * @notice KillMailSystem is a system for reporting kill mail data for on-chain logic
 */
contract KillMailSystem is SmartObjectFramework {
  error KillMail_AlreadyExists(uint256 killMailId);
  error KillMail_InvalidCharacterId(uint256 killMailId, uint256 characterId);

  function reportKill(uint256 killMailId, KillMailData memory killMailData) public access(0) {
    // require valid character ids for submitted killmail data
    if (!Characters.getExists(killMailData.killerCharacterId)) {
      revert KillMail_InvalidCharacterId(killMailId, killMailData.killerCharacterId);
    }
    if (!Characters.getExists(killMailData.victimCharacterId)) {
      revert KillMail_InvalidCharacterId(killMailId, killMailData.victimCharacterId);
    }

    // require killmail does not already exist
    if (KillMail.getKillerCharacterId(killMailId) != 0) {
      revert KillMail_AlreadyExists(killMailId);
    }

    KillMail.set(killMailId, killMailData);
  }
}
