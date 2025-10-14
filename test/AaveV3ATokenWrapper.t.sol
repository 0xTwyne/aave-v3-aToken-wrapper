// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IRewardsController, IAaveV3Pool, AaveV3ATokenWrapper} from "src/AaveV3ATokenWrapper.sol";
import {IERC20}  from "lib/aave-v3-origin/lib/solidity-utils/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}  from "lib/aave-v3-origin/lib/solidity-utils/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

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
    address aToken =0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8; 
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

        tokenWrapper = new AaveV3ATokenWrapper(
            0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb)
        );
        tokenWrapper.initialize(
            aToken,
            address(this),
            "A-Stat-WETH",
            "ASWETH"
        );


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


    function a_withdraw(uint shares) public {
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

    function test_fuzz_deposit(uint amount) public {
        vm.assume(amount <= DEPOSIT_AMOUNT && amount > 100);
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

    function test_rebalanceTokens() public {
        aave_createDeposit();
        vm.startPrank(alice);
        vm.expectRevert(bytes("not collateral vault"));
        
        tokenWrapper.rebalanceATokens(0);

        uint totalAssetsBefore = tokenWrapper.totalAssets();        
        collateralVaultFactory.setIsCollateral(alice, true);
        uint amountExpected = tokenWrapper.previewRedeem(1e18);

        tokenWrapper.rebalanceATokens(1e18);

        assertEq(IERC20(aToken).balanceOf(alice), amountExpected, "Not received correct amount");
        assertEq(tokenWrapper.previewRedeem(1e18), amountExpected, "Preview redeem should give same value");
        assertEq(tokenWrapper.totalAssets(), totalAssetsBefore, "Total assets not same");
        vm.stopPrank();
    }


    function test_burnShares() public {
        aave_createDeposit();
        a_deposit(10e18);
        vm.startPrank(alice);
        vm.expectRevert(bytes("not collateral vault"));
        
        tokenWrapper.burnShares(0);

        uint amountExpected = tokenWrapper.previewRedeem(1e18);
        uint totalSupplyBefore = tokenWrapper.totalSupply();
        uint aliceSharesBefore = tokenWrapper.balanceOf(alice);
        collateralVaultFactory.setIsCollateral(alice, true);
        // previewWithdraw uses CEIL in convertToShares rounding
        uint expectedSharesToBurn = tokenWrapper.previewWithdraw(1e18);
        tokenWrapper.burnShares(1e18);

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


}
