// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

/**
 * @title IERC721System
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IERC721System {
  function evefrontier__balanceOf(address owner) external view returns (uint256);

  function evefrontier__ownerOf(uint256 tokenId) external view returns (address);

  function evefrontier__name() external view returns (string memory);

  function evefrontier__symbol() external view returns (string memory);

  function evefrontier__tokenURI(uint256 tokenId) external view returns (string memory);

  function evefrontier__approve(address to, uint256 tokenId) external;

  function evefrontier__getApproved(uint256 tokenId) external view returns (address);

  function evefrontier__setApprovalForAll(address operator, bool approved) external;

  function evefrontier__isApprovedForAll(address owner, address operator) external view returns (bool);

  function evefrontier__transferFrom(address from, address to, uint256 tokenId) external;

  function evefrontier__safeTransferFrom(address from, address to, uint256 tokenId) external;

  function evefrontier__safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

  function evefrontier__mint(address to, uint256 tokenId) external;

  function evefrontier__safeMint(address to, uint256 tokenId) external;

  function evefrontier__safeMint(address to, uint256 tokenId, bytes memory data) external;

  function evefrontier__burn(uint256 tokenId) external;
}
