// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { WorldContextProviderLib } from "@latticexyz/world/src/WorldContext.sol";
import { IWorldKernel } from "@latticexyz/world/src/IWorldKernel.sol";

import { Id, IdLib } from "../../libs/Id.sol";
import { TAG_SYSTEM } from "../../types/tagTypes.sol";
import { ENTITY_CLASS, ENTITY_OBJECT } from "../../types/entityTypes.sol";
import { Objects } from "../../codegen/tables/Objects.sol";
import { ClassSystemTagMap } from "../../codegen/tables/ClassSystemTagMap.sol";
import { ExecutionContext } from "../../codegen/tables/ExecutionContext.sol";
import { CallContext } from "../../codegen/tables/CallContext.sol";
import { Nonces } from "../../codegen/tables/Nonces.sol";

import { IEntryForwarder } from "../../interfaces/IEntryForwarder.sol";
import { IErrors } from "../../interfaces/IErrors.sol";

import { Utils as EntryForwarderUtils } from "../entry-forwarder/Utils.sol";

/**
 * @title SmartObjectSystem
 * @author CCP Games
 * @dev Extends the standard MUD System.sol with Smart Object Framework functionality
 */
contract SmartObjectSystem is System {
  uint256 constant MUD_CONTEXT_BYTES = 20 + 32;

  /**
   * @dev A modifier to capture (and enforce) Execution Context for Smart Object Framework integrated Systems
   */
  modifier context() {
    ResourceId systemId = SystemRegistry.get(address(this));

    if (_executionId() == bytes32(0)) {
      WorldContextProviderLib.delegatecallWithContext({
        msgSender: _msgSender(),
        msgValue: _msgValue(),
        target: Systems.getSystem(EntryForwarderUtils.entryForwarderSystemId()),
        callData: abi.encodeCall(IEntryForwarder.call, (systemId, msg.data))
      });
    }

    // safety check the callId and executionId
    // reconstruct callId from current calldata
    uint256 callNonce = Nonces.getNonce(keccak256(abi.encodePacked(_msgSender(), systemId, msg.sig, block.number)));
    bytes32 callId = keccak256(abi.encodePacked(_msgSender(), systemId, msg.sig, block.number, callNonce - 1));

    // fetch the CallContext.executionId and sanity check against the stored _executionId() and the ExecutionContext.callHistory
    // these checks will always pass unless the incoming call didn't use _call() (or there is intervening hook logic messing with the execution arguments)
    bytes32 callExecutionId = CallContext.getExecutionId(callId);
    if (_executionId() != callExecutionId) {
      revert IErrors.InvalidExecution(_executionId(), callExecutionId);
    }
    bytes32[] memory callHistory = ExecutionContext.getCallHistory(callExecutionId);
    bytes32 lastCallId = callHistory[callHistory.length - 1];
    // ensure that the current call has been the last populated in the execution context
    if (callId != lastCallId) {
      revert IErrors.InvalidCall(callId, lastCallId);
    }

    _;
  }

  function _executionId() internal view returns (bytes32) {
    bytes32 executionId;
    assembly {
      executionId := tload(0)
    }
    return executionId;
  }

  // the execution entrypoint interacting account (msg.sender, delegator, or payload signer - depending on World entrypoint)
  function _executionMsgSender() internal view returns (address) {
    return CallContext.getMsgSender(ExecutionContext.getItemCallHistory(_executionId(), 0));
  }

  // the execution entrypoint msg value
  function _executionMsgValue() internal view returns (uint256) {
    return CallContext.getMsgValue(ExecutionContext.getItemCallHistory(_executionId(), 0));
  }

  // _call wrapper function for executing and recording context for internal world.call() executions
  function _call(ResourceId systemId, bytes calldata callData) internal returns (bytes memory) {
    if (_executionId() == bytes32(0)) {
      // this is the World entry call of the execution

      // commented out: I'm not sure we need this check yet
      // // if we are not coming through the Dispatcher System on the first jump of our execution, then revert
      // if(address(this) != Systems.getSystem(DISPATCHER_SYSTEM_ID)) {
      //   revert IErrors.
      // }

      bytes32 executionId = _setExecutionContext(systemId, callData);

      _setCallContext(systemId, callData, executionId);
    } else {
      // case: this is a subsequent internal call of an execution

      _setCallContext(systemId, callData, _executionId());
    }

    return IWorldKernel(_world()).call(systemId, callData);
  }

  /**
   * @dev A modifier to enforce Entity based System accessibility scope
   * @param entityId The Object (or Class) Entity to enforce System accessibility for
   * Expected behaviour:
   * if `entityId` is passed as a zero value - system scope enforcement is ignored
   * if `entityId` is passed as an ENTITY_CLASS type ID - system scope enforcement for that Class is applied
   * if `entityId` is passed as an ENTITY_OBJECT type ID - system scope enforcement for the Object's inherited Class is applied
   * if `entityId` is passed as some other (non-Entity) type of ID - revert with an InvalidEntityType error
   */
  modifier scope(Id entityId) {
    ResourceId systemId = SystemRegistry.get(address(this));
    _scope(entityId, systemId);
    _;
  }

  function _scope(Id entityId, ResourceId systemId) private view {
    if (Id.unwrap(entityId) != bytes32(0)) {
      bool classHasTag;
      if (entityId.getType() == ENTITY_CLASS) {
        classHasTag = ClassSystemTagMap.getHasTag(entityId, Id.wrap(ResourceId.unwrap(systemId)));
        if (!classHasTag) {
          revert IErrors.UnscopedSystemCall(entityId, systemId);
        }
      } else if (entityId.getType() == ENTITY_OBJECT) {
        Id classId = Objects.getClass(entityId);
        classHasTag = ClassSystemTagMap.getHasTag(classId, Id.wrap(ResourceId.unwrap(systemId)));
        if (!(classHasTag)) {
          revert IErrors.UnscopedSystemCall(entityId, systemId);
        }
      } else {
        revert IErrors.InvalidEntityType(entityId.getType());
      }
    }
  }

  function _setExecutionContext(ResourceId systemId, bytes calldata callData) private returns (bytes32) {
    bytes32 executionNonceId = keccak256(abi.encodePacked(_msgSender(), systemId, callData[:4], block.number));

    // calc executionId
    // Because we always delegatecall to the EntryForwarder (from the first System/function call of the World entry) as our first action,
    // - _msgSender() will be the original assinged MUD _msgSender() from one of the entry points world.call, world.fallback, world.callFrom, or world.callWithSignature
    // - systemId and functionId will always be the systemId and functionId of the entry point target call
    bytes32 executionId = keccak256(
      abi.encodePacked(_msgSender(), systemId, callData[:4], block.number, Nonces.getNonce(executionNonceId))
    );

    // santiy check executionId is unique
    if (ExecutionContext.getExists(executionId)) {
      revert IErrors.InvalidExecutionId(executionId);
    }

    // store the executionId in transient storage for lookup in subsequent calls of the execution
    assembly {
      tstore(0, executionId)
    }

    // set default ExecutionContext
    ExecutionContext.set(executionId, true, block.number, new bytes32[](0));

    // update execution nonce
    uint256 executionNonce = Nonces.getNonce(executionNonceId);
    Nonces.setNonce(executionNonceId, executionNonce + 1);

    return executionId;
  }

  function _setCallContext(ResourceId systemId, bytes calldata callData, bytes32 executionId) private {
    // bytes32 callNonceId = keccak256(abi.encodePacked(address(this), systemId, callData[:4], block.number))
    // calc callId
    bytes32 callId = keccak256(
      abi.encodePacked(
        address(this),
        systemId,
        callData[:4],
        block.number,
        Nonces.getNonce(keccak256(abi.encodePacked(address(this), systemId, callData[:4], block.number)))
      )
    );

    // santiy check callId is unique
    if (CallContext.getExists(callId)) {
      revert IErrors.InvalidCallId(callId);
    }

    // set CallContext
    CallContext.set(
      callId,
      true,
      executionId,
      _msgSender(),
      _msgValue(),
      systemId,
      bytes4(callData[:4]),
      bytes(callData[4:callData.length - MUD_CONTEXT_BYTES])
    );

    // add our call to the ExecutionContext.callHistory
    ExecutionContext.pushCallHistory(executionId, callId);

    // update Call Nonce
    Nonces.set(
      keccak256(abi.encodePacked(address(this), systemId, callData[:4], block.number)),
      true,
      Nonces.getNonce(keccak256(abi.encodePacked(address(this), systemId, callData[:4], block.number))) + 1
    );
  }
}
