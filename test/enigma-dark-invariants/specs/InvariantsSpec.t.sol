// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV):
    ///   - Properties that should always hold true in the system.
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         ERC4626                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_ERC4626_A =
        "INV_ERC4626_A: The total value locked in the system in underlying assets should always equal or exceed the value redeemable by all share holders combined"; // TODO

    string constant INV_ERC4626_B =
        "INV_ERC4626_B: The sum of all individual share balances should equal the total supply"; // TODO

    string constant INV_ERC4626_C = "INV_ERC4626_C: totalSupply == 0 => totalAssets == 0"; // TODO

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ATOKEN                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_ATOKEN_A =
        "INV_ATOKEN_A: aToken.balanceOf(wrapper) >= totalAssets()"; // TODO

    string constant INV_ATOKEN_B =
        "INV_ATOKEN_B: aToken.scaledBalanceOf(wrapper) >= totalAssets()"; // TODO

    
}
