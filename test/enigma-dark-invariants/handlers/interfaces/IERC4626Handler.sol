// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IERC4626Handler
/// @notice Interface for the ERC4626Handler
interface IERC4626Handler {
    function deposit(uint256 assets) external;
    function mint(uint256 shares) external;
    function withdraw(uint256 assets) external;
    function redeem(uint256 shares) external;
    function transfer(uint256 amount, uint8 i) external;
}
