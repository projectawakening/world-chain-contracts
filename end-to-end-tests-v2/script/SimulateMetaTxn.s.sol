// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IWorldCall } from "@latticexyz/world/src/IWorldKernel.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { ERC2771Forwarder } from "@eveworld/standard-contracts-v2/src/metatx/ERC2771ForwarderWithHashNonce.sol";
import { Tenant, EntityRecordMetadata, EntityRecordMetadataData, Characters, CharactersData, CharactersByAccount } from "@eveworld/world-v2/src/namespaces/evefrontier/codegen/index.sol";

import { EntityRecordParams, EntityMetadataParams } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/entity-record/types.sol";

import { SmartCharacterSystem, smartCharacterSystem } from "@eveworld/world-v2/src/namespaces/evefrontier/systems/smart-character/SmartCharacterSystem.sol";
import { ObjectIdLib } from "@eveworld/world-v2/src/namespaces/evefrontier/libraries/ObjectIdLib.sol";

contract SimulateMetaTxn is Script {
  uint256 signerPrivatekey;
  address signer;

  function run(address worldAddress) public {
    StoreSwitch.setStoreAddress(worldAddress);
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    ERC2771Forwarder erc2771Forwarder = ERC2771Forwarder(vm.envAddress("FORWARDER_ADDRESS"));
    vm.startBroadcast(deployerPrivateKey);

    signerPrivatekey = 0xA11CE;
    signer = vm.addr(signerPrivatekey);
    uint256 nonce = uint256(keccak256(abi.encodePacked("ab")));

    uint256 characterItemId = 12345;
    uint256 characterTypeId = vm.envUint("CHARACTER_TYPE_ID");

    bytes32 tenantId = Tenant.get();
    uint256 characterSmartObjectId = ObjectIdLib.calculateSingletonId(tenantId, characterItemId);

    EntityRecordParams memory entityRecordParams = EntityRecordParams({
      tenantId: tenantId,
      typeId: characterTypeId,
      itemId: characterItemId,
      volume: 0
    });
    EntityMetadataParams memory entityRecordMetadataParams = EntityMetadataParams({
      name: "xxx",
      dappURL: "xxx",
      description: "xxx"
    });

    bytes memory data = abi.encodeWithSelector(
      SmartCharacterSystem.createCharacter.selector,
      characterSmartObjectId,
      signer,
      100,
      entityRecordParams,
      entityRecordMetadataParams
    );
    ResourceId systemId = smartCharacterSystem.toResourceId();
    bytes memory callData = abi.encodeWithSelector(IWorldCall.callFrom.selector, signer, systemId, data);

    // console.logBytes(callData);

    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: signer,
      to: worldAddress,
      value: 0,
      gas: 12000000,
      nonce: nonce,
      deadline: uint48(block.timestamp + 1000),
      data: callData
    });

    // Make this EIP712 complaint
    bytes32 digest = erc2771Forwarder.structHash(req);

    // Sign the request
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivatekey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    ERC2771Forwarder.ForwardRequestData memory requestData = ERC2771Forwarder.ForwardRequestData({
      from: req.from,
      to: req.to,
      value: req.value,
      gas: req.gas,
      nonce: req.nonce,
      deadline: req.deadline,
      data: req.data,
      signature: signature
    });

    bool verified = erc2771Forwarder.verify(requestData);
    console.log(verified);

    erc2771Forwarder.execute(requestData);
    vm.stopBroadcast();
  }
}
