// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IAaveV3ATokenWrapperHandler
/// @notice Interface for the AaveV3ATokenWrapperHandler
interface IAaveV3ATokenWrapperHandler {
    function depositATokens(uint256 assets, uint8 i) external;
    function depositWithPermit(uint256 assets, bool depositToAave, uint8 i) external;
    function redeemATokens(uint256 shares, uint8 i) external;
    function rebalanceATokens_CV(uint256 shares) external;
    function burnShares_CV(uint256 shares) external;
}
