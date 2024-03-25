// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ECDSA } from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "openzeppelin-contracts/utils/Nonces.sol";
import { ERC2771Forwarder } from "../src/metatx/ERC2771ForwarderWithHashNonce.sol";
import { ITasksSystem } from "./worldInterface/ITasksSystem.sol";
import { ISmartCharacterSystem } from "./worldInterface/ISmartCharacterSystem.sol";
import { EntityRecordData, SmartObjectData } from "./worldInterface/types.sol";

contract CallWorld is Script {
  ERC2771Forwarder internal _erc2771Forwarder;
  uint256 _signerPrivatekey;
  address internal _signer;

  function setUp() public {
    _erc2771Forwarder = ERC2771Forwarder(vm.envOr("FORWARDER_ADDRESS", address(0x0)));
  }

  function run(address worldAddress) public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    _signerPrivatekey = 0xA11CE;
    _signer = vm.addr(_signerPrivatekey);

    uint256 nonce = uint256(keccak256(abi.encodePacked("a")));

    // bytes memory data = abi.encodeWithSelector(ITasksSystem.completeTask.selector, 1);
    // console.logBytes(data);

    bytes memory data = abi.encodeWithSelector(
      ISmartCharacterSystem.frontier__createCharacter.selector,
      123,
      0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
      EntityRecordData({ typeId: 123, itemId: 222, volume: 0 }),
      SmartObjectData({ owner: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8, tokenURI: "https://example.com/token/123" })
    );

    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: _signer,
      to: worldAddress,
      value: 0,
      gas: 200000,
      nonce: nonce,
      deadline: uint48(block.timestamp + 1000),
      data: data
    });

    //Make this EIP712 complaint
    bytes32 digest = _erc2771Forwarder.structHash(req);

    //Sign the request
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivatekey, digest);
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

    bool verified = _erc2771Forwarder.verify(requestData);
    console.log(verified);

    _erc2771Forwarder.execute(requestData);
    vm.stopBroadcast();
  }
}
