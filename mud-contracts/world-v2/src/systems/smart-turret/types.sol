// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

struct TargetPriority {
  SmartTurretTarget target;
  uint256 weight;
}

struct SmartTurretTarget {
  uint256 shipId;
  uint256 shipTypeId;
  uint256 characterId;
  uint256 hpRatio;
  uint256 shieldRatio;
  uint256 armorRatio;
}

struct Turret {
  uint256 weaponTypeId;
  uint256 ammoTypeId;
  uint256 chargesLeft;
}
