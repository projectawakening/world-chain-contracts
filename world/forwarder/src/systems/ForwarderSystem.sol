pragma solidity >=0.8.21;
import { System } from "@latticexyz/world/src/System.sol";
import { GlobalStaticData } from "../codegen/index.sol";

contract ForwarderSystem is System {
  /**
   * @dev Set the Forwarder Contract address so that Forwarder contract is a trusted origin
   * @param forwarder - address of the Forwarder contract
   */
  function setTrustedForwarder(address forwarder) external {
    GlobalStaticData.setValue(forwarder, true);
  }

  /**
   * @dev Check if the Forwarder Contract address is a trusted origin
   * This function is required for the forwarder contract to execute meta transactions
   * @param forwarder - address of the Forwarder contract
   */
  function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
    return GlobalStaticData.getValue(forwarder);
  }
}
