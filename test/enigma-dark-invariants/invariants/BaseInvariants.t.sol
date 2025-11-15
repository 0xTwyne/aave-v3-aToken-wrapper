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
        uint256 wrapperATokenBalance = aToken.scaledBalanceOf(address(aaveV3ATokenWrapper));

        assertGe(cvATokenBalance + wrapperATokenBalance, redeemableAssetsSum, INV_ERC4626_A);
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
            aToken.balanceOf(address(aaveV3ATokenWrapper)) + aToken.balanceOf(collateralVault),
            aaveV3ATokenWrapper.totalAssets(),
            INV_ATOKEN_A
        );
    }

    function assert_INV_ATOKEN_B() internal {
        assertEq(
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
}
