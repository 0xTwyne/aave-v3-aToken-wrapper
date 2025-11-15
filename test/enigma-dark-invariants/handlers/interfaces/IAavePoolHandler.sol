// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IAavePoolHandler
/// @notice Interface for the AavePoolHandler
interface IAavePoolHandler {
    function aave_supply(uint256 amount, uint8 i) external;
    function aave_withdraw(uint256 amount, uint8 i) external;
    function aave_borrow(uint256 amount, uint8 i) external;
    function aave_repay(uint256 amount, uint8 i) external;
    function aave_liquidateActor(uint256 debtToCover, bool receiveAToken, uint8 i, uint8 j, uint8 k) external;
}
