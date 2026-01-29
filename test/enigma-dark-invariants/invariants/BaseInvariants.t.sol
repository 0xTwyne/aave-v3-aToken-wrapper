// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_ERC4626_AB() internal {
        uint256 redeemableAssetsSum;
        uint256 shareBalancesSum;
        for (uint8 i; i < NUMBER_OF_ACTORS; i++) {
            address actor_ = actorAddresses[i];

            redeemableAssetsSum += aaveV3ATokenWrapper.previewRedeem(aaveV3ATokenWrapper.balanceOf(actor_));
            shareBalancesSum += aaveV3ATokenWrapper.balanceOf(actor_);
        }

        uint256 cvATokenBalance = aToken.balanceOf(collateralVault);
        uint256 wrapperATokenBalance = aToken.balanceOf(address(aaveV3ATokenWrapper));

        /// @dev add 1 wei tolerance to account for rounding down on the extra balanceOf calls due to aToken's rounding behavior
        assertGe(cvATokenBalance + wrapperATokenBalance + 1, redeemableAssetsSum, INV_ERC4626_A);

        assertEq(shareBalancesSum, aaveV3ATokenWrapper.totalSupply(), INV_ERC4626_B);
    }

    function assert_INV_ERC4626_C() internal {
        if (aaveV3ATokenWrapper.totalSupply() == 0) {
            assertEq(aaveV3ATokenWrapper.totalAssets(), 0, INV_ERC4626_C);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ATOKEN                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_ATOKEN_A() internal {
        assertGe(
            aToken.balanceOf(address(aaveV3ATokenWrapper)) + aToken.balanceOf(collateralVault) + 1,
            aaveV3ATokenWrapper.totalAssets(),
            INV_ATOKEN_A
        );
    }

    function assert_INV_ATOKEN_B() internal {
        assertGe(
            aToken.scaledBalanceOf(address(aaveV3ATokenWrapper)) + aToken.scaledBalanceOf(collateralVault),
            aaveV3ATokenWrapper.totalSupply(),
            INV_ATOKEN_B
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        AVAILABILITY                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_AVAILABILITY_A() internal {
        try aaveV3ATokenWrapper.totalAssets() {}
        catch {
            fail(INV_AVAILABILITY_A);
        }
    }

    function assert_INV_AVAILABILITY_B() internal {
        try aaveV3ATokenWrapper.latestAnswer() {}
        catch {
            fail(INV_AVAILABILITY_B);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      ERC4626 INVARIANTS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_DEPOSIT_INVARIANT_A() internal {
        try aaveV3ATokenWrapper.maxDeposit(address(0)) {}
        catch {
            fail(ERC4626_DEPOSIT_INVARIANT_A);
        }
    }

    function assert_ERC4626_MINT_INVARIANT_A() internal {
        try aaveV3ATokenWrapper.maxMint(address(0)) {}
        catch {
            fail(ERC4626_MINT_INVARIANT_A);
        }
    }

    function assert_ERC4626_WITHDRAW_INVARIANT_A() internal {
        try aaveV3ATokenWrapper.maxWithdraw(address(0)) {}
        catch {
            fail(ERC4626_WITHDRAW_INVARIANT_A);
        }
    }

    function assert_ERC4626_REDEEM_INVARIANT_A() internal {
        try aaveV3ATokenWrapper.maxRedeem(address(0)) {}
        catch {
            fail(ERC4626_REDEEM_INVARIANT_A);
        }
    }
}
