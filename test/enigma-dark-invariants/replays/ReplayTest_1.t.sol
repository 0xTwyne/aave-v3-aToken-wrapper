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

contract ReplayTest1 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest1 Tester = this;

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
    
    
    function test_replay_1_rebalanceATokens_CV() public {
        _setUpActor(USER1);
        Tester.aave_supply(22712, 0);
        Tester.aave_supply(2, 1);
        Tester.depositATokens(101730958244318843076968, 0);
        Tester.aave_borrow(21500, 0);
        _delay(966509);
        Tester.rebalanceATokens_CV(2);
        
    }
    
    function test_replay_1_setLatestAnswer() public {
        _setUpActor(USER1);
        Tester.setLatestAnswer(817750159926398873, 1);
        _checkInvariants();
    }
    
    function test_replay_1_depositWithPermit() public {
        _setUpActor(USER1);
        Tester.aave_supply(2, 0);
        Tester.aave_supply(2, 1);
        Tester.aave_borrow(1, 0);
        _delay(1);
        Tester.depositWithPermit(7024725750834853511895836, false, 0);
        
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