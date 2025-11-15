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
        "INV_ERC4626_A: The total value locked in the system in underlying assets should always equal or exceed the value redeemable by all share holders combined";

    string constant INV_ERC4626_B =
        "INV_ERC4626_B: The sum of all individual share balances should equal the total supply";

    string constant INV_ERC4626_C = "INV_ERC4626_C: totalSupply == 0 => totalAssets == 0";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ATOKEN                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_ATOKEN_A =
        "INV_ATOKEN_A: aToken.balanceOf(wrapper) + aToken.balanceOf(collateral vault) >= totalAssets()";

    string constant INV_ATOKEN_B =
        "INV_ATOKEN_B: aToken.scaledBalanceOf(wrapper) + aToken.scaledBalanceOf(collateral vault) == totalSupply()";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        AVAILABILITY                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_AVAILABILITY_A = "INV_AVAILABILITY_A: aaveV3ATokenWrapper.totalAssets() should never revert";

    string constant INV_AVAILABILITY_B = "INV_AVAILABILITY_B: aaveV3ATokenWrapper.latestAnswer() should never revert";
}
