// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IRewardsController, IAaveV3Pool, AaveV3ATokenWrapper} from "src/AaveV3ATokenWrapper.sol";
import {IERC20}  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}  from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

contract MockCollateralVaultFactory {

    mapping(address => bool) isCollateral;

    function setIsCollateral(address asset, bool status) external {
        isCollateral[asset] = status;
    }

    function isCollateralVault(address asset) external view returns (bool) {
        return isCollateral[asset];
    }
}

contract AaveV3ATokenWrapperTest is Test {
    AaveV3ATokenWrapper tokenWrapper;

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    MockCollateralVaultFactory collateralVaultFactory;
    IAaveV3Pool aavePool = IAaveV3Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address aToken = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address owner;
    address alice;
    address bob;
    uint DEPOSIT_AMOUNT_INIT = 100 ether;
    uint DEPOSIT_AMOUNT = 20 ether;

    function setUp() public {
        owner = makeAddr('owner');
        alice = makeAddr('alice');
        bob = makeAddr('bob');

        collateralVaultFactory = new MockCollateralVaultFactory();

        // Deploy implementation
        address implementation = address(new AaveV3ATokenWrapper(
            0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb)
        ));

        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            AaveV3ATokenWrapper.initialize.selector,
            aToken,
            address(this),
            "A-Stat-WETH",
            "ASWETH"
        );

        // Deploy proxy
        address proxy = address(new ERC1967Proxy(implementation, initData));
        tokenWrapper = AaveV3ATokenWrapper(proxy);

        deal(WETH, alice, DEPOSIT_AMOUNT);
        deal(WETH, bob, DEPOSIT_AMOUNT_INIT);
    }

    function depositToAave(address user, address asset, uint amount) internal {
        vm.startPrank(user);

        IERC20(asset).approve(address(aavePool), amount);

        aavePool.supply(asset, amount, user, 0);

        vm.stopPrank();
    }


    function aave_createDeposit() public {
        vm.startPrank(bob);

        IERC20(WETH).approve(address(tokenWrapper), DEPOSIT_AMOUNT_INIT);
        uint expectedShares = tokenWrapper.previewDeposit(DEPOSIT_AMOUNT_INIT);

        tokenWrapper.deposit(DEPOSIT_AMOUNT_INIT, bob);

        vm.stopPrank();
        assertEq(tokenWrapper.balanceOf(bob), expectedShares, "Incorrect shares received");
    }

    function a_deposit(uint amount) public {
        vm.startPrank(alice);
        uint expectedShares = tokenWrapper.previewDeposit(amount);
        IERC20(WETH).approve(address(tokenWrapper), amount);

        tokenWrapper.deposit(amount, alice);

        vm.stopPrank();
        assertEq(tokenWrapper.balanceOf(alice), expectedShares, "Incorrect shares received");
    }


    function a_withdraw(uint shares) internal {
        uint balanceBefore = IERC20(WETH).balanceOf(alice);
        vm.startPrank(alice);

        uint amountExpected = tokenWrapper.previewRedeem(shares);
        tokenWrapper.redeem(shares, alice, alice);

        vm.stopPrank();
        assertEq(IERC20(WETH).balanceOf(alice) - balanceBefore, amountExpected);
    }

    function test_deposit() public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);
    }

    function test_withdraw() public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);

        a_withdraw(tokenWrapper.balanceOf(alice));
    }

    function test_fuzz_deposit(uint256 amount) public {
        vm.assume(amount > 100 && amount <= DEPOSIT_AMOUNT);
        aave_createDeposit();
        a_deposit(amount);
    }

    function test_fuzz_withdraw(uint amount) public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);
        uint sharesMax = tokenWrapper.balanceOf(alice);
        vm.assume(amount <= sharesMax && amount > 100);
        a_withdraw(sharesMax);
    }

    function test_rebalanceATokens_CV() public {
        aave_createDeposit();
        vm.startPrank(alice);
        vm.expectRevert(bytes("not collateral vault"));

        tokenWrapper.rebalanceATokens_CV(0);

        uint totalAssetsBefore = tokenWrapper.totalAssets();
        collateralVaultFactory.setIsCollateral(alice, true);
        uint amountExpected = tokenWrapper.previewRedeem(1e18);

        tokenWrapper.rebalanceATokens_CV(1e18);

        assertEq(IERC20(aToken).balanceOf(alice), amountExpected, "Not received correct amount");
        assertEq(tokenWrapper.previewRedeem(1e18), amountExpected, "Preview redeem should give same value");
        assertEq(tokenWrapper.totalAssets(), totalAssetsBefore, "Total assets not same");
        vm.stopPrank();
    }


    function test_burnShares_CV() public {
        aave_createDeposit();
        a_deposit(10e18);
        vm.startPrank(alice);
        vm.expectRevert(bytes("not collateral vault"));

        tokenWrapper.burnShares_CV(0);

        uint amountExpected = tokenWrapper.previewRedeem(1e18);
        uint totalSupplyBefore = tokenWrapper.totalSupply();
        uint aliceSharesBefore = tokenWrapper.balanceOf(alice);
        collateralVaultFactory.setIsCollateral(alice, true);
        // previewWithdraw uses CEIL in convertToShares rounding
        uint expectedSharesToBurn = tokenWrapper.previewWithdraw(1e18);
        tokenWrapper.burnShares_CV(1e18);

        assertEq(tokenWrapper.previewRedeem(1e18), amountExpected, "Preview redeem should give same value");
        assertEq(tokenWrapper.totalSupply(), totalSupplyBefore - expectedSharesToBurn, "Total supply after is not expected");
        assertEq(tokenWrapper.balanceOf(alice), aliceSharesBefore - expectedSharesToBurn, "Expected shares to burn are not same");
        vm.stopPrank();
    }

    function test_donationAttack() public {

        uint firstDeposit = 2;

        address attacker = makeAddr("attacker");

        deal(WETH, attacker, 100e18);

        vm.startPrank(attacker);

        IERC20(WETH).approve(address(tokenWrapper), 100e18);
        tokenWrapper.deposit(firstDeposit, attacker);
        vm.stopPrank();

        depositToAave(attacker, WETH, 10e18);

        uint balance = IERC20(aToken).balanceOf(attacker);
        vm.prank(attacker);
        IERC20(aToken).transfer(address(tokenWrapper), balance);

        a_deposit(1e18);

        assertGe(tokenWrapper.balanceOf(alice), 5e17);

        vm.startPrank(attacker);
        uint assetsReceived = tokenWrapper.redeem(tokenWrapper.balanceOf(attacker), attacker, attacker);
        assertLt(assetsReceived, 10e18);
    }

    // Test pause functionality
    function test_pauseUnpause() public {
        aave_createDeposit();

        // Only owner can pause
        vm.prank(alice);
        vm.expectRevert();
        tokenWrapper.setPaused(true);

        // Owner pauses
        vm.prank(address(this));
        tokenWrapper.setPaused(true);
        assertTrue(tokenWrapper.paused());

        // Operations should fail when paused
        vm.startPrank(alice);
        vm.expectRevert();
        tokenWrapper.deposit(1e18, alice);
        vm.stopPrank();

        // Owner unpauses
        vm.prank(address(this));
        tokenWrapper.setPaused(false);
        assertFalse(tokenWrapper.paused());

        // Operations should work again
        a_deposit(DEPOSIT_AMOUNT);
    }

    // Test ERC4626 mint function
    function test_mint() public {
        aave_createDeposit();

        uint sharesToMint = 10e18;
        uint assetsRequired = tokenWrapper.previewMint(sharesToMint);

        deal(WETH, alice, assetsRequired);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(tokenWrapper), assetsRequired);
        uint assetsUsed = tokenWrapper.mint(sharesToMint, alice);
        vm.stopPrank();

        assertEq(tokenWrapper.balanceOf(alice), sharesToMint);
        assertEq(assetsUsed, assetsRequired);
    }

    // Test ERC4626 withdraw function
    function test_withdrawAssets() public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);

        uint assetsToWithdraw = 5e18;
        uint sharesRequired = tokenWrapper.previewWithdraw(assetsToWithdraw);
        uint balanceBefore = IERC20(WETH).balanceOf(alice);

        vm.startPrank(alice);
        uint sharesUsed = tokenWrapper.withdraw(assetsToWithdraw, alice, alice);
        vm.stopPrank();

        assertEq(sharesUsed, sharesRequired);
        assertEq(IERC20(WETH).balanceOf(alice) - balanceBefore, assetsToWithdraw);
    }

    // Test max functions
    function test_maxDeposit() public {
        aave_createDeposit();

        // Max deposit should be greater than 0 when not paused
        uint256 maxDep = tokenWrapper.maxDeposit(alice);
        assertGt(maxDep, 0);

        // When paused, deposits should revert (not necessarily return 0)
        vm.prank(address(this));
        tokenWrapper.setPaused(true);

        // Try to deposit when paused - should revert
        vm.startPrank(alice);
        vm.expectRevert();
        tokenWrapper.deposit(1e18, alice);
        vm.stopPrank();
    }

    function test_maxMint() public {
        aave_createDeposit();

        // Max mint should be greater than 0 when not paused
        uint256 maxM = tokenWrapper.maxMint(alice);
        assertGt(maxM, 0);

        // When paused, minting should revert (not necessarily return 0)
        vm.prank(address(this));
        tokenWrapper.setPaused(true);

        // Try to mint when paused - should revert
        vm.startPrank(alice);
        vm.expectRevert();
        tokenWrapper.mint(1e18, alice);
        vm.stopPrank();
    }

    function test_maxWithdraw() public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);

        uint maxAssets = tokenWrapper.maxWithdraw(alice);
        uint expectedMax = tokenWrapper.previewRedeem(tokenWrapper.balanceOf(alice));

        assertEq(maxAssets, expectedMax);
    }

    function test_maxRedeem() public {
        aave_createDeposit();
        a_deposit(DEPOSIT_AMOUNT);

        uint maxShares = tokenWrapper.maxRedeem(alice);
        assertEq(maxShares, tokenWrapper.balanceOf(alice));
    }

    // Test rebalanceATokens_CV edge cases
    function test_rebalanceATokens_CV_multipleRebalances() public {
        aave_createDeposit();
        collateralVaultFactory.setIsCollateral(alice, true);

        vm.startPrank(alice);
        IERC20(aToken).approve(address(tokenWrapper), type(uint256).max);

        // First rebalance - get some aTokens
        uint expectedATokenBalance_CV = tokenWrapper.previewRedeem(10e18);
        uint aliceShares = tokenWrapper.balanceOf(alice);
        tokenWrapper.rebalanceATokens_CV(10e18);
        uint firstBalance = IERC20(aToken).balanceOf(alice);
        assertEq(firstBalance, expectedATokenBalance_CV, "Should receive exact expected aTokens");
        assertEq(tokenWrapper.balanceOf(alice), aliceShares, "Should receive exact expected aTokens");

        // Second rebalance - increase position
        tokenWrapper.rebalanceATokens_CV(20e18);
        uint secondBalance = IERC20(aToken).balanceOf(alice);
        assertGt(secondBalance, firstBalance);

        // Third rebalance - decrease position
        tokenWrapper.rebalanceATokens_CV(5e18);
        uint thirdBalance = IERC20(aToken).balanceOf(alice);
        assertLt(thirdBalance, secondBalance);

        vm.stopPrank();
    }

    function test_rebalanceATokens_CV_withExcessATokens() public {
        aave_createDeposit();
        collateralVaultFactory.setIsCollateral(alice, true);

        // Give alice some aTokens directly
        depositToAave(alice, WETH, 10e18);
        uint initialATokenBalance = IERC20(aToken).balanceOf(alice);

        // Rebalance to a smaller amount
        vm.startPrank(alice);
        IERC20(aToken).approve(address(tokenWrapper), type(uint256).max);
        tokenWrapper.rebalanceATokens_CV(1e18);
        vm.stopPrank();

        // Alice should have less aTokens now
        uint finalATokenBalance = IERC20(aToken).balanceOf(alice);
        assertLt(finalATokenBalance, initialATokenBalance);

        // Allow for small rounding differences (1 wei)
        uint expectedBalance = tokenWrapper.previewRedeem(1e18);
        assertLe(finalATokenBalance, expectedBalance + 1);
        assertGe(finalATokenBalance, expectedBalance - 1);
    }

    // Test burnShares_CV with various amounts
    function test_burnShares_CV_partialBurn() public {
        aave_createDeposit();
        a_deposit(20e18);

        collateralVaultFactory.setIsCollateral(alice, true);

        uint initialBalance = tokenWrapper.balanceOf(alice);
        uint burnAmount = 5e18;
        uint expectedSharesToBurn = tokenWrapper.previewWithdraw(burnAmount);

        vm.prank(alice);
        tokenWrapper.burnShares_CV(burnAmount);

        assertEq(tokenWrapper.balanceOf(alice), initialBalance - expectedSharesToBurn);
    }

    function test_burnShares_CV_fullBurn() public {
        aave_createDeposit();
        a_deposit(10e18);

        collateralVaultFactory.setIsCollateral(alice, true);

        // Calculate how much to burn to clear all shares
        uint allShares = tokenWrapper.balanceOf(alice);
        uint assetsEquivalent = tokenWrapper.previewRedeem(allShares);

        vm.prank(alice);
        tokenWrapper.burnShares_CV(assetsEquivalent);

        // Alice should have 0 or very small amount due to rounding
        assertLe(tokenWrapper.balanceOf(alice), 1);
    }

    // Test interactions between CV functions
    function test_CV_functions_interaction() public {
        aave_createDeposit();
        a_deposit(20e18);

        collateralVaultFactory.setIsCollateral(alice, true);

        vm.startPrank(alice);

        // Approve the wrapper to transfer aTokens
        IERC20(aToken).approve(address(tokenWrapper), type(uint256).max);

        // First rebalance to get aTokens
        tokenWrapper.rebalanceATokens_CV(10e18);
        uint aTokenBalance = IERC20(aToken).balanceOf(alice);

        // Burn some shares
        tokenWrapper.burnShares_CV(5e18);

        // Rebalance should still work correctly after burn
        tokenWrapper.rebalanceATokens_CV(5e18);
        uint newATokenBalance = IERC20(aToken).balanceOf(alice);

        // Should have less aTokens after burning shares and rebalancing to lower amount
        assertLt(newATokenBalance, aTokenBalance);

        vm.stopPrank();
    }

    // Test that non-collateral vaults cannot call CV functions
    function test_CV_functions_accessControl() public {
        aave_createDeposit();
        a_deposit(10e18);

        // Bob is not a collateral vault
        vm.startPrank(bob);

        vm.expectRevert(bytes("not collateral vault"));
        tokenWrapper.rebalanceATokens_CV(1e18);

        vm.expectRevert(bytes("not collateral vault"));
        tokenWrapper.burnShares_CV(1e18);

        vm.stopPrank();

        // After setting bob as collateral vault, functions should work
        collateralVaultFactory.setIsCollateral(bob, true);

        vm.prank(bob);
        tokenWrapper.rebalanceATokens_CV(0); // Should not revert
    }

    // Test convertToShares and convertToAssets
    function test_conversionFunctions() public {
        aave_createDeposit();

        uint assets = 10e18;
        uint shares = tokenWrapper.convertToShares(assets);
        uint assetsBack = tokenWrapper.convertToAssets(shares);

        // Due to rounding, assetsBack might be slightly less than assets
        assertLe(assetsBack, assets);
        assertGe(assetsBack, assets - 10); // Allow small rounding difference
    }

    // Test totalAssets tracking
    function test_totalAssets() public {
        uint initialTotal = tokenWrapper.totalAssets();

        aave_createDeposit();
        uint afterFirstDeposit = tokenWrapper.totalAssets();
        assertGt(afterFirstDeposit, initialTotal);

        a_deposit(DEPOSIT_AMOUNT);
        uint afterSecondDeposit = tokenWrapper.totalAssets();
        assertGt(afterSecondDeposit, afterFirstDeposit);

        // Total assets should be at least close to deposits (allowing for small rounding)
        assertGe(afterSecondDeposit, DEPOSIT_AMOUNT_INIT + DEPOSIT_AMOUNT - 1e15);
    }

    // Test owner functions
    function test_ownershipTransfer() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        tokenWrapper.transferOwnership(newOwner);
        assertEq(tokenWrapper.owner(), newOwner);

        // Old owner can't pause anymore
        vm.expectRevert();
        tokenWrapper.setPaused(true);

        // New owner can pause
        vm.prank(newOwner);
        tokenWrapper.setPaused(true);
        assertTrue(tokenWrapper.paused());
    }

    // Fuzzing test for rebalanceATokens with scaledBalance verification
    function test_fuzz_rebalanceATokens_scaledBalance(uint256 depositAmount, uint256 iterations) public {
        // Bound the input values
        depositAmount = bound(depositAmount, 1e18, 100e18); // Between 1 and 100 WETH
        iterations = bound(iterations, 1, 5); // Do 1-5 iterations of deposits/rebalances
        
        // Setup: Create initial deposit to avoid division by zero
        aave_createDeposit();
        
        // Make alice a collateral vault
        address vault = alice;
        collateralVaultFactory.setIsCollateral(vault, true);
        
        // Give vault some WETH and deposit to wrapper
        deal(WETH, vault, depositAmount * 2); // Give extra for later deposits
        vm.startPrank(vault);
        IERC20(WETH).approve(address(tokenWrapper), type(uint256).max);
        tokenWrapper.deposit(depositAmount, vault);
        
        // Get initial wrapper balance
        uint256 wrapperBalance = tokenWrapper.balanceOf(vault);
        
        // Approve wrapper to transfer aTokens
        IAToken aTokenContract = IAToken(aToken);
        IERC20(aToken).approve(address(tokenWrapper), type(uint256).max);
        
        // Call rebalanceATokens_CV with the vault's wrapper balance
        tokenWrapper.rebalanceATokens_CV(wrapperBalance);
        
        // Verify that scaledBalanceOf(vault) equals wrapper.balanceOf(vault)
        uint256 scaledBalance = aTokenContract.scaledBalanceOf(vault);
        assertEq(scaledBalance, wrapperBalance, "Scaled balance should equal wrapper balance after rebalance");
        
        vm.stopPrank();
        
        // Additional verification: Do multiple rounds with different amounts
        for (uint256 i = 0; i < iterations; i++) {
            vm.startPrank(vault);
            
            // Get current balances
            uint256 currentWrapperBalance = tokenWrapper.balanceOf(vault);
            uint256 currentWETHBalance = IERC20(WETH).balanceOf(vault);
            
            if (i % 2 == 0 && currentWrapperBalance > 1e17) {
                // Withdraw some (but not too much)
                uint256 withdrawAmount = bound(uint256(keccak256(abi.encode("withdraw", i))), 1e17, currentWrapperBalance / 2);
                tokenWrapper.redeem(withdrawAmount, vault, vault);
            } else if (currentWETHBalance >= 1e17) {
                // Deposit more
                uint256 depositAmt = bound(uint256(keccak256(abi.encode("deposit", i))), 1e17, currentWETHBalance);
                tokenWrapper.deposit(depositAmt, vault);
            }
            
            // Get updated wrapper balance
            wrapperBalance = tokenWrapper.balanceOf(vault);
            
            // Rebalance again
            if (wrapperBalance > 0) {
                tokenWrapper.rebalanceATokens_CV(wrapperBalance);
                
                // Verify equality again
                scaledBalance = aTokenContract.scaledBalanceOf(vault);
                assertEq(scaledBalance, wrapperBalance, 
                    string.concat("Iteration ", vm.toString(i), ": Scaled balance should equal wrapper balance"));
            }
            
            vm.stopPrank();
        }
    }
    
    // Additional test: Verify rebalanceATokens with partial shares
    function test_fuzz_rebalanceATokens_partialShares(uint256 depositAmount, uint256 sharesFraction) public {
        // Bound inputs
        depositAmount = bound(depositAmount, 10e18, 100e18);
        sharesFraction = bound(sharesFraction, 1, 100); // 1-100% of balance
        
        aave_createDeposit();
        
        address vault = alice;
        collateralVaultFactory.setIsCollateral(vault, true);
        
        // Deposit and get shares
        deal(WETH, vault, depositAmount);
        vm.startPrank(vault);
        IERC20(WETH).approve(address(tokenWrapper), depositAmount);
        tokenWrapper.deposit(depositAmount, vault);
        
        uint256 totalShares = tokenWrapper.balanceOf(vault);
        uint256 partialShares = (totalShares * sharesFraction) / 100;
        
        // Approve and rebalance with partial shares
        IAToken aTokenContract = IAToken(aToken);
        IERC20(aToken).approve(address(tokenWrapper), type(uint256).max);
        
        tokenWrapper.rebalanceATokens_CV(partialShares);
        
        // Verify scaled balance equals the partial shares
        uint256 scaledBalance = aTokenContract.scaledBalanceOf(vault);
        assertEq(scaledBalance, partialShares, "Scaled balance should equal requested partial shares");
        
        // Rebalance to full amount
        tokenWrapper.rebalanceATokens_CV(totalShares);
        scaledBalance = aTokenContract.scaledBalanceOf(vault);
        assertEq(scaledBalance, totalShares, "Scaled balance should equal total shares after full rebalance");
        
        vm.stopPrank();
    }
}
