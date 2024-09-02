// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

struct Target {
  string char;
  string shipType;
  uint256 weight;
  HPRatio hpRatio;
}

struct HPRatio {
  uint256 armor;
  uint256 hp;
  uint256 shield;
}
