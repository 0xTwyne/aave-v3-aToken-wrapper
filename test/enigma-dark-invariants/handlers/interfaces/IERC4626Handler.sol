// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IERC4626Handler
/// @notice Interface for the ERC4626Handler
interface IERC4626Handler {
    function deposit(uint256 assets) external returns (uint256 addedShares);
    function mint(uint256 shares) external returns (uint256 addedAssets);
    function withdraw(uint256 assets) external returns (uint256 removedShares);
    function redeem(uint256 shares) external returns (uint256 removedAssets);
    function transfer(uint256 amount, uint8 i) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_A(uint256 amount) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_B(uint256 amount) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_C(uint256 shares) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_D(uint256 shares) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_E(uint256 shares) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_F(uint256 shares) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_G(uint256 amount) external;
    function assert_ERC4626_ROUNDTRIP_INVARIANT_H(uint256 amount) external;
}
