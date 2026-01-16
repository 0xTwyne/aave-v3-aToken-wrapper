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

contract ReplayTest2 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest2 Tester = this;

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

    function test_replay_2_depositWithPermit() public {
        _setUpActor(USER1);
        _delay(259275);
        Tester.deposit(4789011);
        _setUpActor(USER3);
        _delay(1);
        //Tester.deposit(4493973539772574522520517502494487869333938913467484600271534879115);
        _setUpActor(USER2);
        _delay(899146);
        Tester.aave_supply(15381550, 0);
        _delay(25);
        Tester.aave_borrow(1, 142);
        _setUpActor(USER1);
        _delay(215691);
        Tester.redeemATokens(249749, 117);
        _delay(519780);
        console.log("vault.totalSupply", aaveV3ATokenWrapper.totalSupply());
        Tester.depositWithPermit(
            14474029471542223877891850970916573276737765129795458900905245151159264133492, false, 124
        );
        _checkInvariants();
    }

    function test_replay_2_rebalanceATokens_CV() public {
        _setUpActor(USER3);
        _delay(1);
        Tester.deposit(25008361481);
        _setUpActor(USER2);
        _delay(899146);
        Tester.aave_supply(18014119336608560, 177);
        _delay(1966868);
        Tester.aave_borrow(11306, 62);
        _setUpActor(USER1);
        _delay(359341);
        Tester.depositWithPermit(
            16283268410490459558355274291391871276949792474378345200087377085686380064627, true, 87
        );
        _setUpActor(USER3);
        _delay(8);
        Tester.rebalanceATokens_CV(62501906001571325);
        _checkInvariants();
    }

    function test_replay_2_assert_ERC4626_ROUNDTRIP_INVARIANT_D() public {
        _setUpActor(USER1);
        _delay(259275);
        Tester.deposit(152450459345210);
        _setUpActor(USER3);
        _delay(1);
        _setUpActor(USER2);
        _delay(899146);
        Tester.aave_supply(16896009, 0);
        _delay(25);
        Tester.aave_borrow(57351, 68);
        _setUpActor(USER1);
        _delay(359821);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_D(35184372419530);
    }

    function test_replay_2_depositATokens() public {
        _setUpActor(USER1);
        _delay(259275);
        Tester.deposit(47228624458730);
        _setUpActor(USER3);
        _delay(1);
        _setUpActor(USER2);
        _delay(899146);
        Tester.aave_supply(15625000000000004397979421490, 49);
        _delay(25);
        Tester.aave_borrow(1553948, 6);
        _setUpActor(USER1);
        _delay(500513);
        Tester.redeemATokens(4194226, 37);
        _setUpActor(USER2);
        _delay(360584);
        Tester.depositATokens(14135063016202708959399284392876917919057579982223693152082619210336864349, 0);
        _checkInvariants();
    }

    /// @notice Test if regular deposit() also causes scaledBalance != totalSupply
    function test_replay_2_deposit_invariant_check() public {
        // Capture initial state
        uint256 scaledBefore = aToken.scaledBalanceOf(address(aaveV3ATokenWrapper));
        uint256 supplyBefore = aaveV3ATokenWrapper.totalSupply();

        console.log("=== BEFORE DEPOSIT ===");
        console.log("scaledBalanceOf(wrapper):", scaledBefore);
        console.log("totalSupply:", supplyBefore);

        // Do a deposit using regular deposit() - depositToAave=true path
        _setUpActor(USER1);
        _delay(259275);
        Tester.deposit(4789011); // Same amount as depositWithPermit test

        // Check state after
        uint256 scaledAfter = aToken.scaledBalanceOf(address(aaveV3ATokenWrapper));
        uint256 supplyAfter = aaveV3ATokenWrapper.totalSupply();

        console.log("=== AFTER DEPOSIT ===");
        console.log("scaledBalanceOf(wrapper):", scaledAfter);
        console.log("totalSupply:", supplyAfter);
        console.log("scaledBalance increase:", scaledAfter - scaledBefore);
        console.log("totalSupply increase:", supplyAfter - supplyBefore);
        console.log("difference:", int256(scaledAfter) - int256(supplyAfter));

        // Check invariant
        _checkInvariants();
    }

    /// @notice Same sequence as test_replay_2_depositWithPermit but using deposit() instead
    function test_replay_2_deposit_vs_depositWithPermit() public {
        _setUpActor(USER1);
        _delay(259275);
        Tester.deposit(4789011);
        _setUpActor(USER3);
        _delay(1);
        _setUpActor(USER2);
        _delay(899146);
        Tester.aave_supply(15381550, 0);
        _delay(25);
        Tester.aave_borrow(1, 142);
        _setUpActor(USER1);
        _delay(215691);
        Tester.redeemATokens(249749, 117);
        _delay(519780);

        console.log("=== BEFORE SECOND DEPOSIT ===");
        console.log("scaledBalanceOf(wrapper):", aToken.scaledBalanceOf(address(aaveV3ATokenWrapper)));
        console.log("totalSupply:", aaveV3ATokenWrapper.totalSupply());

        // Use regular deposit() instead of depositWithPermit
        // The original used: depositWithPermit(14474029..., false, 124) where false = depositToAave
        // Let's use deposit() which uses depositToAave=true
        Tester.deposit(249748); // Similar amount

        console.log("=== AFTER SECOND DEPOSIT ===");
        console.log("scaledBalanceOf(wrapper):", aToken.scaledBalanceOf(address(aaveV3ATokenWrapper)));
        console.log("totalSupply:", aaveV3ATokenWrapper.totalSupply());
        console.log(
            "difference:",
            int256(aToken.scaledBalanceOf(address(aaveV3ATokenWrapper))) - int256(aaveV3ATokenWrapper.totalSupply())
        );

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
