// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

contract ReplayTest6 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest6 Tester = this;

    modifier setup() override {
        _;
    }

    function setUp() public {
        // Etch the create2 factory
        _etchCreate2Factory();

        // Deploy protocol contracts
        _setUp();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   		REPLAY TESTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_6_rebalanceATokens_CV1() public {
        _setUpActor(USER1);
        Tester.aave_supply(21976, 0);
        Tester.aave_supply(2, 1);
        Tester.depositATokens(21694, 0);
        Tester.aave_borrow(18381, 0);
        _delay(966509);
        console.log("before rebalanceATokens_CV1");
        console.log("aToken.scaledBalanceOf(collateralVault)", aToken.scaledBalanceOf(collateralVault));
        console.log("aToken.balanceOf(collateralVault)", aToken.balanceOf(collateralVault));
        console.log("aToken.balanceOf(aaveV3ATokenWrapper)", aToken.balanceOf(address(aaveV3ATokenWrapper)));
        Tester.rebalanceATokens_CV(1);
        console.log("after rebalanceATokens_CV1");
        console.log("aToken.scaledBalanceOf(collateralVault)", aToken.scaledBalanceOf(collateralVault));
        console.log("aToken.balanceOf(collateralVault)", aToken.balanceOf(collateralVault));
        console.log("aToken.balanceOf(aaveV3ATokenWrapper)", aToken.balanceOf(address(aaveV3ATokenWrapper)));
        _checkInvariants();
    }

    function test_replay_6_rebalanceATokens_CV2() public {
        _setUpActor(USER1);
        Tester.aave_supply(21976, 0);
        Tester.aave_supply(2, 1);
        Tester.depositATokens(21694, 0);
        Tester.aave_borrow(18381, 0);
        _delay(966509);
        Tester.rebalanceATokens_CV(1);
        _checkInvariants();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
