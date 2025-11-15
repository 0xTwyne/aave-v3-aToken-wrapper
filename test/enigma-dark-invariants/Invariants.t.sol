// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function invariant_INV_ERC4626() public returns (bool) {
        assert_INV_ERC4626_AB();
        assert_INV_ERC4626_C();

        return true;
    }

    function invariant_INV_ATOKEN() public returns (bool) {
        assert_INV_ATOKEN_A();
        assert_INV_ATOKEN_B();

        return true;
    }

    function invariant_INV_AVAILABILITY() public returns (bool) {
        assert_INV_AVAILABILITY_A();
        assert_INV_AVAILABILITY_B();

        return true;
    }
}
