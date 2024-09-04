//SPDX-LicenseIdentifier: MIT
pragma solidity >=0.8.24;

interface ISmartCharacterErrors {
  error SmartCharacter_ERC721AlreadyInitialized();
  error SmartCharacter_UndefinedClassIds();
  error SmartCharacterDoesNotExist(uint256 characterId);
}
