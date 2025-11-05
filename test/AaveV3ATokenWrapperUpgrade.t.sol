// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";

// Mock implementation for testing upgrades
contract AaveV3ATokenWrapperV2 is AaveV3ATokenWrapper {
    constructor(
        address _evc,
        address _collateralVaultFactory,
        IAaveV3Pool _aavePool,
        IRewardsController rewardsController
    ) AaveV3ATokenWrapper(_evc, _collateralVaultFactory, _aavePool, rewardsController) {}

    // Override version to demonstrate upgrade
    function version() external pure override returns (uint) {
        return 2;
    }

    // New function in V2
    function newFeature() external pure returns (string memory) {
        return "This is a new feature in V2";
    }
}

contract MockCollateralVaultFactory {
    address public immutable EVC;
    mapping(address => bool) isCollateral;

    constructor(address _evc) {
        EVC = _evc;
    }

    function setIsCollateral(address asset, bool status) external {
        isCollateral[asset] = status;
    }

    function isCollateralVault(address asset) external view returns (bool) {
        return isCollateral[asset];
    }
}

contract AaveV3ATokenWrapperUpgradeTest is Test {
    // Mainnet addresses
    address constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    IAaveV3Pool constant aavePool = IAaveV3Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address constant aToken = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371; // aWSTETH

    AaveV3ATokenWrapper public proxy;
    address public implementation;
    MockCollateralVaultFactory public collateralVaultFactory;

    address owner;
    address alice;

    function setUp() public {
        owner = makeAddr('owner');
        alice = makeAddr('alice');

        collateralVaultFactory = new MockCollateralVaultFactory(EVC);

        // Deploy implementation
        implementation = address(new AaveV3ATokenWrapper(
            EVC,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(address(AToken(aToken).REWARDS_CONTROLLER()))
        ));

        // Encode initialization data
        bytes memory initData = abi.encodeCall(
            AaveV3ATokenWrapper.initialize,
            (aToken, owner, "UUPS Test Wrapper", "UUPS-WRAP")
        );

        // Deploy proxy
        vm.prank(owner);
        address proxyAddress = address(new ERC1967Proxy(implementation, initData));
        proxy = AaveV3ATokenWrapper(proxyAddress);
    }

    function test_initialDeployment() public view {
        // Check proxy is initialized correctly
        assertEq(proxy.name(), "UUPS Test Wrapper");
        assertEq(proxy.symbol(), "UUPS-WRAP");
        assertEq(proxy.owner(), owner);
        assertEq(proxy.version(), 1);
    }

    function test_upgradeToV2() public {
        // Deploy V2 implementation
        address implementationV2 = address(new AaveV3ATokenWrapperV2(
            EVC,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(address(AToken(aToken).REWARDS_CONTROLLER()))
        ));

        // Try to upgrade as non-owner (should fail)
        vm.prank(alice);
        vm.expectRevert();
        proxy.upgradeToAndCall(implementationV2, "");

        // Upgrade as owner
        vm.prank(owner);
        proxy.upgradeToAndCall(implementationV2, "");

        // Check upgrade was successful
        assertEq(proxy.version(), 2);

        // Check that state is preserved
        assertEq(proxy.name(), "UUPS Test Wrapper");
        assertEq(proxy.symbol(), "UUPS-WRAP");
        assertEq(proxy.owner(), owner);

        // Check new feature is available
        AaveV3ATokenWrapperV2 proxyV2 = AaveV3ATokenWrapperV2(address(proxy));
        assertEq(proxyV2.newFeature(), "This is a new feature in V2");
    }

    function test_storageConsistencyAfterUpgrade() public {
        // First deposit some funds (need mainnet fork)
        deal(WSTETH, alice, 10 ether);

        vm.startPrank(alice);
        IERC20(WSTETH).approve(address(proxy), 10 ether);
        proxy.deposit(10 ether, alice);
        vm.stopPrank();

        uint256 balanceBefore = proxy.balanceOf(alice);
        uint256 totalAssetsBefore = proxy.totalAssets();

        // Upgrade to V2
        address implementationV2 = address(new AaveV3ATokenWrapperV2(
            EVC,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(address(AToken(aToken).REWARDS_CONTROLLER()))
        ));

        vm.prank(owner);
        proxy.upgradeToAndCall(implementationV2, "");

        // Check that balances are preserved
        assertEq(proxy.balanceOf(alice), balanceBefore);
        assertEq(proxy.totalAssets(), totalAssetsBefore);

        // Check that alice can still withdraw
        vm.startPrank(alice);
        uint256 shares = proxy.balanceOf(alice);
        proxy.redeem(shares, alice, alice);
        vm.stopPrank();

        // Should have received back approximately 10 ether
        assertGe(IERC20(WSTETH).balanceOf(alice), 9.99 ether);
    }

    function test_cannotReinitializeAfterUpgrade() public {
        // Deploy V2 implementation
        address implementationV2 = address(new AaveV3ATokenWrapperV2(
            EVC,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(address(AToken(aToken).REWARDS_CONTROLLER()))
        ));

        // Upgrade
        vm.prank(owner);
        proxy.upgradeToAndCall(implementationV2, "");

        // Try to reinitialize (should fail)
        vm.expectRevert();
        proxy.initialize(aToken, alice, "Hacked", "HACK");
    }

    function test_implementationCannotBeUsedDirectly() public {
        AaveV3ATokenWrapper impl = AaveV3ATokenWrapper(implementation);

        // Should revert when trying to initialize implementation directly
        vm.expectRevert();
        impl.initialize(aToken, owner, "Direct", "DIRECT");

        // Should revert when trying to use implementation directly
        vm.expectRevert();
        impl.deposit(1 ether, alice);
    }

    function test_onlyOwnerCanUpgrade() public {
        address implementationV2 = address(new AaveV3ATokenWrapperV2(
            EVC,
            address(collateralVaultFactory),
            aavePool,
            IRewardsController(address(AToken(aToken).REWARDS_CONTROLLER()))
        ));

        // Random user cannot upgrade
        vm.prank(alice);
        vm.expectRevert();
        proxy.upgradeToAndCall(implementationV2, "");

        // Transfer ownership
        vm.prank(owner);
        proxy.transferOwnership(alice);

        // Now alice can upgrade
        vm.prank(alice);
        proxy.upgradeToAndCall(implementationV2, "");

        assertEq(proxy.version(), 2);
    }
}