// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { ERC2771Context } from "openzeppelin-contracts/metatx/ERC2771Context.sol";
import { ERC2771Forwarder } from "../src/metatx/ERC2771ForwarderWithHashNonce.sol";

contract Counter is ERC2771Context {
  uint256 public number;

  constructor(address forwarderContract) ERC2771Context(forwarderContract) {}

  function setNumber(uint256 newNumber) public {
    if (newNumber < 5) {
      revert("Value should be greater than 2");
    }
    number = newNumber;
  }

  function increment() public {
    number++;
  }
}

contract CounterTest is Test {
  Counter public counter;
  ERC2771Forwarder internal _erc2771Forwarder;
  uint256 _signerPrivatekey;
  address internal _signer;

  function setUp() public {
    _erc2771Forwarder = new ERC2771Forwarder("Forwarder");
    counter = new Counter(address(_erc2771Forwarder));
    _signerPrivatekey = 0xA11CE;
    _signer = vm.addr(_signerPrivatekey);
    counter.setNumber(7);
  }

  function test_Increment() public {
    counter.increment();
    assertEq(counter.number(), 8);
  }

  function test_Forwarder() public {
    //Create the forwarder reqeuest
    uint256 nonce = uint256(keccak256(abi.encodePacked("a")));

    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: _signer,
      to: address(counter),
      value: 0,
      gas: 100000,
      nonce: nonce,
      deadline: uint48(block.timestamp + 1000),
      data: abi.encodeCall(counter.setNumber, (12))
    });

    //Make this EIP712 complaint
    bytes32 digest = _erc2771Forwarder.structHash(req);

    //Sign the request
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivatekey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertEq(counter.number(), 7);
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
    assertEq(verified, true);
    _erc2771Forwarder.execute(requestData);

    assertEq(counter.number(), 12);
  }

  function test_revertMessage() public {
    //Create the forwarder reqeuest
    uint256 nonce = uint256(keccak256(abi.encodePacked("a")));
    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: _signer,
      to: address(counter),
      value: 0,
      gas: 100000,
      nonce: nonce,
      deadline: uint48(block.timestamp + 1000),
      data: abi.encodeCall(counter.setNumber, (2))
    });

    //Make this EIP712 complaint
    bytes32 digest = _erc2771Forwarder.structHash(req);

    //Sign the request
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivatekey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertEq(counter.number(), 7);
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
    assertEq(verified, true);
    vm.expectRevert("Value should be greater than 2");
    _erc2771Forwarder.execute(requestData);
  }
}
