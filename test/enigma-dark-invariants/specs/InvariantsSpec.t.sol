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
        "INV_ATOKEN_A: aToken.balanceOf(wrapper) + aToken.balanceOf(collateral vault) + 1 wei tolerance >= totalAssets()";

    string constant INV_ATOKEN_B =
        "INV_ATOKEN_B: aToken.scaledBalanceOf(wrapper) + aToken.scaledBalanceOf(collateral vault) >= totalSupply()";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        AVAILABILITY                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_AVAILABILITY_A = "INV_AVAILABILITY_A: aaveV3ATokenWrapper.totalAssets() should never revert";

    string constant INV_AVAILABILITY_B = "INV_AVAILABILITY_B: aaveV3ATokenWrapper.latestAnswer() should never revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      ERC4626 INVARIANTS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice DEPOSIT

    string constant ERC4626_DEPOSIT_INVARIANT_A = "ERC4626_DEPOSIT_INVARIANT_A: maxDeposit MUST NOT revert";

    string constant ERC4626_DEPOSIT_INVARIANT_B =
        "ERC4626_DEPOSIT_INVARIANT_B: previewDeposit MUST return close to and no more than shares minted at deposit if called in the same transaction";

    /// @notice MINT

    string constant ERC4626_MINT_INVARIANT_A = "ERC4626_MINT_INVARIANT_A: maxMint MUST NOT revert";

    string constant ERC4626_MINT_INVARIANT_B =
        "ERC4626_MINT_INVARIANT_B: previewMint MUST return close to and no fewer than assets deposited at mint if called in the same transaction";

    /// @notice WITHDRAW

    string constant ERC4626_WITHDRAW_INVARIANT_A = "ERC4626_WITHDRAW_INVARIANT_A: maxWithdraw MUST NOT revert";

    string constant ERC4626_WITHDRAW_INVARIANT_B =
        "ERC4626_WITHDRAW_INVARIANT_B: previewWithdraw MUST return close to and no fewer than shares burned at withdraw if called in the same transaction";

    /// @notice REDEEM

    string constant ERC4626_REDEEM_INVARIANT_A = "ERC4626_REDEEM_INVARIANT_A: maxRedeem MUST NOT revert";

    string constant ERC4626_REDEEM_INVARIANT_B =
        "ERC4626_REDEEM_INVARIANT_B: previewRedeem MUST return close to and no more than assets redeemed at redeem if called in the same transaction";

    /// @notice ROUNDTRIP

    string constant ERC4626_ROUNDTRIP_INVARIANT_A = "ERC4626_ROUNDTRIP_INVARIANT_A: redeem(deposit(a)) <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_B =
        "ERC4626_ROUNDTRIP_INVARIANT_B: s = deposit(a) s' = withdraw(a) s' >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_C = "ERC4626_ROUNDTRIP_INVARIANT_C: deposit(redeem(s)) <= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_D = "ERC4626_ROUNDTRIP_INVARIANT_D: a = redeem(s) a' = mint(s) a' >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_E = "ERC4626_ROUNDTRIP_INVARIANT_E: withdraw(mint(s)) >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_F = "ERC4626_ROUNDTRIP_INVARIANT_F: a = mint(s) a' = redeem(s) a' <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_G = "ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_H =
        "ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a) s' = deposit(a) s' <= s";
}
