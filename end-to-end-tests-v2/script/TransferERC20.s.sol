// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IWorldCall } from "@latticexyz/world/src/IWorldKernel.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { IERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20.sol";
import { ERC2771Forwarder } from "@eveworld/standard-contracts-v2/src/metatx/ERC2771ForwarderWithHashNonce.sol";

contract TransferERC20 is Script {
  // Constants
  string private constant MNEMONIC = "test test test test test test test test test test test junk";
  uint256 private constant AMOUNT = 1000000000000;
  uint256 private constant GAS_LIMIT = 12000000;
  uint48 private constant DEADLINE_OFFSET = 1000;

  // State variables
  address erc20Address;
  address worldAddress;
  address forwarderAddress;
  bytes14 eveTokenNamespace;

  function run(address worldAddr) external {
    erc20Address = vm.envAddress("ERC20_CONTRACT_ADDRESS");
    forwarderAddress = vm.envAddress("FORWARDER_ADDRESS");
    eveTokenNamespace = stringToBytes14(vm.envString("EVE_TOKEN_NAMESPACE"));
    worldAddress = worldAddr;

    // Setup accounts
    (address alice, address bob, address charlie) = _setupAccounts();

    // Initialize world and ERC20
    IBaseWorld world = _initializeWorld(worldAddress);
    IERC20Mintable erc20 = IERC20Mintable(erc20Address);

    // Execute transfers with balance checks
    _logBalances(world, alice, bob, charlie, "Initial balances");

    _mintTokens(erc20, alice);
    _logBalances(world, alice, bob, charlie, "After minting to Alice");

    _transferAliceToBob(erc20, alice, bob);
    _logBalances(world, alice, bob, charlie, "After transfer from Alice to Bob");

    _transferAliceToCharlie(world, alice, charlie);
    _logBalances(world, alice, bob, charlie, "After transfer from Alice to Charlie");

    _transferBobToCharlie(bob, charlie);
    _logBalances(world, alice, bob, charlie, "Final balances");
  }

  function _setupAccounts() private returns (address alice, address bob, address charlie) {
    uint256 alicePrivateKey = vm.deriveKey(MNEMONIC, 2);
    uint256 bobPrivateKey = vm.deriveKey(MNEMONIC, 3);
    uint256 charliePrivateKey = vm.deriveKey(MNEMONIC, 4);

    return (vm.addr(alicePrivateKey), vm.addr(bobPrivateKey), vm.addr(charliePrivateKey));
  }

  function _initializeWorld(address worldAddress) private returns (IBaseWorld) {
    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);
    StoreSwitch.setStoreAddress(address(world));
    return world;
  }

  function _mintTokens(IERC20Mintable erc20, address to) private {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    erc20.mint(to, AMOUNT * 1 ether);
    vm.stopBroadcast();

    console.log("Minted tokens to:", to);
    console.log("Amount:", AMOUNT * 1 ether);
  }

  function _transferAliceToBob(IERC20 erc20, address alice, address bob) private {
    uint256 alicePrivateKey = vm.deriveKey(MNEMONIC, 2);
    vm.startBroadcast(alicePrivateKey);
    erc20.transfer(bob, (AMOUNT / 2) * 1 ether);
    vm.stopBroadcast();
  }

  function _transferAliceToCharlie(IBaseWorld world, address alice, address charlie) private {
    uint256 alicePrivateKey = vm.deriveKey(MNEMONIC, 2);
    vm.startBroadcast(alicePrivateKey);
    world.call(erc20SystemId(), abi.encodeCall(IERC20.transfer, (charlie, (AMOUNT / 2) * 1 ether)));
    vm.stopBroadcast();
  }

  function _transferBobToCharlie(address bob, address charlie) private {
    uint256 bobPrivateKey = vm.deriveKey(MNEMONIC, 3);
    vm.startBroadcast(bobPrivateKey);
    _simulateMetaTransaction(bobPrivateKey, bob, charlie, AMOUNT / 2);
    vm.stopBroadcast();
  }

  function _logBalances(IBaseWorld world, address alice, address bob, address charlie, string memory step) private {
    console.log("\n=== %s ===", step);
    console.log("Alice balance:   %s", _balance(world, alice));
    console.log("Bob balance:     %s", _balance(world, bob));
    console.log("Charlie balance: %s", _balance(world, charlie));
  }

  function _balance(IBaseWorld world, address account) private returns (uint256) {
    bytes memory result = world.call(erc20SystemId(), abi.encodeCall(IERC20.balanceOf, (account)));
    return abi.decode(result, (uint256));
  }

  function _simulateMetaTransaction(uint256 signerPrivateKey, address from, address to, uint256 amount) private {
    ERC2771Forwarder erc2771Forwarder = ERC2771Forwarder(forwarderAddress);
    uint256 amountInWei = amount * 1 ether;

    bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, to, amountInWei);
    ResourceId systemId = erc20SystemId();
    bytes memory callData = abi.encodeWithSelector(IWorldCall.callFrom.selector, from, systemId, data);

    uint256 nonce = uint256(keccak256(abi.encodePacked("abac")));

    ERC2771Forwarder.ForwardRequest memory req = ERC2771Forwarder.ForwardRequest({
      from: from,
      to: worldAddress,
      value: 0,
      gas: GAS_LIMIT,
      nonce: nonce,
      deadline: uint48(block.timestamp + DEADLINE_OFFSET),
      data: callData
    });

    bytes32 digest = erc2771Forwarder.structHash(req);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
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
    require(verified, "Meta transaction verification failed");

    erc2771Forwarder.execute(requestData);
  }

  function erc20SystemId() private view returns (ResourceId) {
    bytes14 name = "ERC20System";
    return WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: eveTokenNamespace, name: name });
  }

  function stringToBytes14(string memory str) private pure returns (bytes14) {
    bytes memory tempBytes = bytes(str);
    require(tempBytes.length <= 14, "String too long");

    bytes14 converted;
    for (uint i = 0; i < tempBytes.length; i++) {
      converted |= bytes14(tempBytes[i] & 0xFF) >> (i * 8);
    }
    return converted;
  }
}
