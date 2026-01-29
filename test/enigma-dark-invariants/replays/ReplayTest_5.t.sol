// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @title ReplayTest5
/// @notice Test to verify if redeemATokens has rounding in favor of user
contract ReplayTest5 is Invariants, Setup {
    ReplayTest5 Tester = this;

    modifier setup() override {
        _;
    }

    function setUp() public {
        _etchCreate2Factory();
        _setUp();
        actor = actors[USER1];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   REPLAY TESTS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Test: deposit via standard path, then time passes (interest accrues),
    /// then redeemATokens to check rounding with non-1.0 rate
    function test_replay_5_redeemATokens_rounding() public {
        _setUpActor(USER1);

        // Step 1: Supply to Aave first to have liquidity
        Tester.aave_supply(10 ether, 0);

        // Someone borrows to generate interest
        Tester.aave_borrow(1 ether, 0);

        // Step 2: Deposit underlying via standard path
        uint256 depositAmount = 1 ether;
        (bool success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(IERC4626.deposit, (depositAmount, address(actor)))
        );
        require(success, "deposit failed");

        uint256 sharesReceived = aaveV3ATokenWrapper.balanceOf(address(actor));

        console.log("=== AFTER DEPOSIT ===");
        console.log("Shares received:", sharesReceived);
        console.log("Wrapper scaled balance:", aToken.scaledBalanceOf(address(aaveV3ATokenWrapper)));

        // Step 3: TIME PASSES - interest accrues, rate changes
        _delay(365 days);

        console.log("\n=== AFTER 1 YEAR ===");
        console.log("Wrapper totalAssets (with interest):", aaveV3ATokenWrapper.totalAssets());

        // Step 4: Calculate expected aTokens from shares (with new rate)
        uint256 expectedATokens = aaveV3ATokenWrapper.previewRedeem(sharesReceived);
        console.log("Expected aTokens from previewRedeem:", expectedATokens);

        // Step 5: Check scaled balances before redeem
        uint256 wrapperScaledBefore = aToken.scaledBalanceOf(address(aaveV3ATokenWrapper));
        uint256 userScaledBefore = aToken.scaledBalanceOf(address(actor));

        console.log("\n=== BEFORE REDEEM ATOKENS ===");
        console.log("Wrapper scaled balance:", wrapperScaledBefore);
        console.log("User scaled balance:", userScaledBefore);

        // Step 6: Redeem via redeemATokens
        uint256 userATokenBeforeRedeem = aToken.balanceOf(address(actor));

        (success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (sharesReceived, address(actor), address(actor)))
        );
        require(success, "redeemATokens failed");

        uint256 userATokenAfterRedeem = aToken.balanceOf(address(actor));
        uint256 actualATokensReceived = userATokenAfterRedeem - userATokenBeforeRedeem;

        uint256 wrapperScaledAfter = aToken.scaledBalanceOf(address(aaveV3ATokenWrapper));
        uint256 userScaledAfter = aToken.scaledBalanceOf(address(actor));

        console.log("\n=== AFTER REDEEM ATOKENS ===");
        console.log("Actual aTokens received:", actualATokensReceived);
        console.log("Expected aTokens:", expectedATokens);
        console.log("Difference (actual - expected):", int256(actualATokensReceived) - int256(expectedATokens));
        console.log("Wrapper scaled after:", wrapperScaledAfter);
        console.log("User scaled gained:", userScaledAfter - userScaledBefore);
        console.log("Shares burned:", sharesReceived);
        console.log("Scaled diff (user gained - shares):", int256(userScaledAfter - userScaledBefore) - int256(sharesReceived));

        if (actualATokensReceived > expectedATokens) {
            console.log("\n!!! USER RECEIVED MORE ATOKENS THAN EXPECTED !!!");
        }
    }

    /// @notice Test: Try to extract 1 wei by using exact amounts
    /// The idea: if previewRedeem doesn't round, but aToken transfer does round UP,
    /// user could get 1 wei extra scaled balance
    function test_replay_5_extract_via_exact_redeem() public {
        _setUpActor(USER1);

        // Step 1: Supply to Aave
        Tester.aave_supply(10 ether, 0);
        Tester.aave_borrow(1 ether, 0);

        // Step 2: Deposit underlying (clean path)
        uint256 depositAmount = 1 ether;
        (bool success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(IERC4626.deposit, (depositAmount, address(actor)))
        );
        require(success, "deposit failed");

        uint256 shares = aaveV3ATokenWrapper.balanceOf(address(actor));

        // Step 3: Let time pass to get a non-1.0 rate
        _delay(100 days);

        // Step 4: Get current rate
        uint256 rate = aavePool.getReserveNormalizedIncome(address(weth));
        console.log("Rate:", rate);
        console.log("Shares:", shares);

        // Step 5: Calculate assets from shares (what previewRedeem does)
        // assets = shares * rate / RAY
        uint256 assetsFromPreview = aaveV3ATokenWrapper.previewRedeem(shares);

        // Step 6: Check if previewRedeem rounded
        // If (shares * rate) % RAY != 0, then previewRedeem rounded down
        uint256 exactProduct = shares * rate;
        uint256 remainder = exactProduct % 1e27;

        console.log("\n=== ROUNDING ANALYSIS ===");
        console.log("shares * rate =", exactProduct);
        console.log("Remainder (mod RAY):", remainder);
        console.log("previewRedeem result:", assetsFromPreview);

        if (remainder > 0) {
            console.log("previewRedeem ROUNDED DOWN by", remainder, "/ RAY");
        } else {
            console.log("previewRedeem was EXACT (no rounding)");
        }

        // Step 7: Now the key question - what does aToken transfer do?
        // When wrapper sends `assetsFromPreview` aTokens, how much scaled balance does user get?

        // aToken transfer scaled amount = rayDiv(amount, rate)
        // rayDiv = (a * RAY + rate/2) / rate  (rounds to nearest)
        // OR rayDivCeil = (a * RAY + rate - 1) / rate (rounds up)

        uint256 expectedScaledViaRayDiv = (assetsFromPreview * 1e27 + rate / 2) / rate;
        uint256 expectedScaledViaRayDivCeil = (assetsFromPreview * 1e27 + rate - 1) / rate;

        console.log("\n=== EXPECTED SCALED BALANCE FROM TRANSFER ===");
        console.log("If rayDiv (round nearest):", expectedScaledViaRayDiv);
        console.log("If rayDivCeil (round up):", expectedScaledViaRayDivCeil);
        console.log("Shares being burned:", shares);

        // Step 8: Actually do the redeem and check
        uint256 userScaledBefore = aToken.scaledBalanceOf(address(actor));

        (success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (shares, address(actor), address(actor)))
        );
        require(success, "redeemATokens failed");

        uint256 userScaledAfter = aToken.scaledBalanceOf(address(actor));
        uint256 actualScaledGained = userScaledAfter - userScaledBefore;

        console.log("\n=== ACTUAL RESULT ===");
        console.log("Actual scaled gained:", actualScaledGained);
        console.log("Shares burned:", shares);
        console.log("Difference (gained - burned):", int256(actualScaledGained) - int256(shares));

        if (actualScaledGained > shares) {
            console.log("\n!!! USER EXTRACTED", actualScaledGained - shares, "WEI EXTRA SCALED BALANCE !!!");
        } else if (actualScaledGained < shares) {
            console.log("\n--- Protocol kept", shares - actualScaledGained, "wei (favorable) ---");
        } else {
            console.log("\n--- Exact match ---");
        }
    }

    /// @notice Test: Use exact amounts where previewRedeem has NO rounding
    /// By using shares = rate, we ensure (shares * rate) % RAY is more likely to be 0
    function test_replay_5_exact_no_rounding() public {
        _setUpActor(USER1);

        // Step 1: Supply to Aave
        Tester.aave_supply(100 ether, 0);
        Tester.aave_borrow(10 ether, 0);

        // Step 2: Let time pass to get a non-1.0 rate
        _delay(30 days);

        // Step 3: Get current rate
        uint256 rate = aavePool.getReserveNormalizedIncome(address(weth));
        console.log("Rate:", rate);

        // Step 4: Use shares = RAY so that previewRedeem gives exactly `rate` assets
        // shares * rate / RAY = RAY * rate / RAY = rate (exact!)
        uint256 sharesToTest = 1e27; // RAY

        // First we need to get these shares via deposit
        // previewMint tells us how many assets we need for sharesToTest shares
        uint256 assetsNeeded = aaveV3ATokenWrapper.previewMint(sharesToTest);
        console.log("Assets needed to mint RAY shares:", assetsNeeded);

        // Deposit to get the shares
        (bool success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(IERC4626.deposit, (assetsNeeded, address(actor)))
        );
        require(success, "deposit failed");

        uint256 sharesGot = aaveV3ATokenWrapper.balanceOf(address(actor));
        console.log("Shares received:", sharesGot);

        // Step 5: Check previewRedeem calculation
        uint256 assetsFromPreview = aaveV3ATokenWrapper.previewRedeem(sharesGot);
        uint256 exactProduct = sharesGot * rate;
        uint256 remainder = exactProduct % 1e27;

        console.log("\n=== ROUNDING CHECK ===");
        console.log("shares * rate:", exactProduct);
        console.log("Remainder:", remainder);
        console.log("previewRedeem:", assetsFromPreview);

        // Step 6: Do the redeem
        uint256 userScaledBefore = aToken.scaledBalanceOf(address(actor));

        (success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (sharesGot, address(actor), address(actor)))
        );
        require(success, "redeemATokens failed");

        uint256 userScaledAfter = aToken.scaledBalanceOf(address(actor));
        uint256 actualScaledGained = userScaledAfter - userScaledBefore;

        console.log("\n=== RESULT ===");
        console.log("Shares burned:", sharesGot);
        console.log("Scaled gained:", actualScaledGained);
        console.log("Diff:", int256(actualScaledGained) - int256(sharesGot));

        // The critical assertion: user should never gain more scaled balance than shares burned
        assertLe(actualScaledGained, sharesGot, "USER EXTRACTED VALUE!");
    }

    /// @notice Test: depositATokens -> redeemATokens cycle
    /// depositATokens: user loses (gets fewer shares than aTokens deposited)
    /// redeemATokens: does user gain it back?
    function test_replay_5_depositATokens_redeemATokens_cycle() public {
        _setUpActor(USER1);

        // Step 1: Supply to Aave to get aTokens
        Tester.aave_supply(10 ether, 0);
        Tester.aave_borrow(1 ether, 0);

        // Step 2: Let time pass
        _delay(100 days);

        uint256 rate = aavePool.getReserveNormalizedIncome(address(weth));
        console.log("Rate:", rate);

        // Step 3: User has aTokens from supply, deposit them to wrapper
        uint256 userATokensBefore = aToken.balanceOf(address(actor));
        uint256 userScaledBefore = aToken.scaledBalanceOf(address(actor));
        console.log("User aTokens before:", userATokensBefore);
        console.log("User scaled before:", userScaledBefore);

        uint256 depositAmount = 1 ether;

        (bool success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.depositATokens, (depositAmount, address(actor)))
        );
        require(success, "depositATokens failed");

        uint256 sharesReceived = aaveV3ATokenWrapper.balanceOf(address(actor));
        uint256 userScaledAfterDeposit = aToken.scaledBalanceOf(address(actor));
        uint256 scaledLostOnDeposit = userScaledBefore - userScaledAfterDeposit;

        console.log("\n=== AFTER depositATokens ===");
        console.log("Shares received:", sharesReceived);
        console.log("Scaled lost:", scaledLostOnDeposit);
        console.log("Diff (shares - scaled lost):", int256(sharesReceived) - int256(scaledLostOnDeposit));

        // Step 4: Now redeem via redeemATokens
        uint256 previewAssets = aaveV3ATokenWrapper.previewRedeem(sharesReceived);
        console.log("\npreviewRedeem:", previewAssets);

        (success,) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (sharesReceived, address(actor), address(actor)))
        );
        require(success, "redeemATokens failed");

        uint256 userScaledAfterRedeem = aToken.scaledBalanceOf(address(actor));
        uint256 scaledGainedOnRedeem = userScaledAfterRedeem - userScaledAfterDeposit;

        console.log("\n=== AFTER redeemATokens ===");
        console.log("Scaled gained:", scaledGainedOnRedeem);
        console.log("Shares burned:", sharesReceived);
        console.log("Diff (gained - burned):", int256(scaledGainedOnRedeem) - int256(sharesReceived));

        // Net effect
        int256 netScaledChange = int256(userScaledAfterRedeem) - int256(userScaledBefore);
        console.log("\n=== NET EFFECT ===");
        console.log("Net scaled change:", netScaledChange);

        if (netScaledChange > 0) {
            console.log("!!! USER EXTRACTED", uint256(netScaledChange), "WEI !!!");
        } else if (netScaledChange < 0) {
            console.log("--- Protocol gained", uint256(-netScaledChange), "wei ---");
        } else {
            console.log("--- Exact break-even ---");
        }

        // User should not profit from the cycle
        assertLe(netScaledChange, int256(0), "USER EXTRACTED VALUE!");
    }

    /// @notice Test: Multiple deposit/redeemATokens cycles to accumulate rounding
    function test_replay_5_multiple_cycles() public {
        _setUpActor(USER1);

        // Supply to Aave first
        Tester.aave_supply(100 ether, 0);

        uint256 cycles = 10;
        uint256 depositAmount = 0.1 ether;

        uint256 totalExpected;
        uint256 totalActual;

        for (uint256 i = 0; i < cycles; i++) {
            // Deposit underlying
            (bool success,) = actor.proxy(
                address(aaveV3ATokenWrapper),
                abi.encodeCall(IERC4626.deposit, (depositAmount, address(actor)))
            );
            if (!success) break;

            uint256 shares = aaveV3ATokenWrapper.balanceOf(address(actor));
            uint256 expected = aaveV3ATokenWrapper.previewRedeem(shares);
            totalExpected += expected;

            uint256 aTokenBefore = aToken.balanceOf(address(actor));

            // Redeem aTokens
            (success,) = actor.proxy(
                address(aaveV3ATokenWrapper),
                abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (shares, address(actor), address(actor)))
            );
            if (!success) break;

            uint256 actual = aToken.balanceOf(address(actor)) - aTokenBefore;
            totalActual += actual;
        }

        console.log("=== AFTER", cycles, "CYCLES ===");
        console.log("Total expected aTokens:", totalExpected);
        console.log("Total actual aTokens:", totalActual);
        console.log("Cumulative difference:", int256(totalActual) - int256(totalExpected));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }
}
