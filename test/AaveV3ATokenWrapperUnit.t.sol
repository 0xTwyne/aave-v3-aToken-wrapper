// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3ATokenWrapper, IRewardsController} from "src/AaveV3ATokenWrapper.sol";
import {
    AaveV3ATokenWrapperMigration,
    InvalidFinalImplementationVersion,
    InvalidFinalImplementationCollateralVaultFactory,
    InvalidFinalImplementationEVC,
    MigrationImplementationCannotBeFinal
} from "src/AaveV3ATokenWrapperMigration.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUnderlyingToken is ERC20 {
    constructor() ERC20("Mock Underlying", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockAToken is ERC20 {
    address public immutable POOL;
    address public immutable UNDERLYING_ASSET_ADDRESS;

    constructor(address pool, address underlying) ERC20("Mock AToken", "aMCK") {
        POOL = pool;
        UNDERLYING_ASSET_ADDRESS = underlying;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == POOL, "only pool");
        _mint(to, amount);
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }
}

contract MockPool {
    address public immutable ADDRESSES_PROVIDER;
    MockUnderlyingToken public immutable underlying;
    MockAToken public aToken;
    uint256 public immutable normalizedIncome;

    constructor(address underlyingAsset, uint256 reserveNormalizedIncome) {
        ADDRESSES_PROVIDER = address(1);
        underlying = MockUnderlyingToken(underlyingAsset);
        normalizedIncome = reserveNormalizedIncome;
    }

    function setAToken(address aTokenAddress) external {
        require(address(aToken) == address(0), "aToken already set");
        aToken = MockAToken(aTokenAddress);
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) public {
        require(asset == address(underlying), "unsupported asset");
        underlying.transferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount);
    }

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        supply(asset, amount, onBehalfOf, referralCode);
    }

    function getReserveNormalizedIncome(address asset) external view returns (uint256) {
        require(asset == address(underlying), "unsupported asset");
        return normalizedIncome;
    }
}

contract MockCollateralVaultFactoryUnit {
    address public immutable EVC;

    constructor(address evc) {
        EVC = evc;
    }

    function isCollateralVault(address) external pure returns (bool) {
        return false;
    }
}

contract AaveV3ATokenWrapperV3Mock is AaveV3ATokenWrapper {
    constructor(
        address _evc,
        address _collateralVaultFactory,
        IPool _aavePool,
        IRewardsController rewardsController
    ) AaveV3ATokenWrapper(_evc, _collateralVaultFactory, _aavePool, rewardsController) {}

    function version() external pure override returns (uint) {
        return 3;
    }
}

contract AaveV3ATokenWrapperWrongEVCMock is AaveV3ATokenWrapper {
    address internal immutable fakeEvc;

    constructor(
        address _evc,
        address _collateralVaultFactory,
        IPool _aavePool,
        IRewardsController rewardsController,
        address _fakeEvc
    ) AaveV3ATokenWrapper(_evc, _collateralVaultFactory, _aavePool, rewardsController) {
        fakeEvc = _fakeEvc;
    }

    function EVC() external view override returns (address) {
        return fakeEvc;
    }
}

contract AaveV3ATokenWrapperUnitTest is Test {
    uint256 internal constant RATE = 1e27;

    AaveV3ATokenWrapper internal tokenWrapper;
    MockUnderlyingToken internal underlying;
    MockPool internal pool;
    MockAToken internal aToken;
    address internal owner;

    address internal alice;
    address internal bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        owner = address(this);

        underlying = new MockUnderlyingToken();
        pool = new MockPool(address(underlying), RATE);
        aToken = new MockAToken(address(pool), address(underlying));
        pool.setAToken(address(aToken));

        address evc = makeAddr("evc");
        MockCollateralVaultFactoryUnit collateralVaultFactory = new MockCollateralVaultFactoryUnit(evc);

        address implementation = address(
            new AaveV3ATokenWrapper(
                evc,
                address(collateralVaultFactory),
                IPool(address(pool)),
                IRewardsController(makeAddr("rewardsController"))
            )
        );

        bytes memory initData = abi.encodeCall(
            AaveV3ATokenWrapper.initialize,
            (address(aToken), owner, "A-Stat-Mock", "ASTATMOCK")
        );

        tokenWrapper = AaveV3ATokenWrapper(address(new ERC1967Proxy(implementation, initData)));
    }

    function test_skim_thenDeposit_nonZeroAmount() public {
        uint256 skimAmount = 1 ether;
        uint256 depositAmount = 2 ether;

        assertEq(underlying.allowance(address(tokenWrapper), address(pool)), type(uint256).max);

        underlying.mint(address(tokenWrapper), skimAmount);
        tokenWrapper.skim(alice);

        assertEq(tokenWrapper.balanceOf(alice), skimAmount, "Skim should mint shares");
        assertEq(underlying.allowance(address(tokenWrapper), address(pool)), type(uint256).max, "Skim should preserve max allowance");

        underlying.mint(bob, depositAmount);
        vm.startPrank(bob);
        underlying.approve(address(tokenWrapper), depositAmount);

        uint256 expectedShares = tokenWrapper.previewDeposit(depositAmount);
        uint256 mintedShares = tokenWrapper.deposit(depositAmount, bob);
        vm.stopPrank();

        assertGt(expectedShares, 0, "Deposit preview should return non-zero shares");
        assertEq(mintedShares, expectedShares, "Deposit should mint previewed shares after skim");
        assertEq(tokenWrapper.balanceOf(bob), expectedShares, "Bob should receive wrapper shares");
        assertEq(tokenWrapper.totalSupply(), skimAmount + expectedShares, "Total supply should include skim and deposit shares");
        assertEq(underlying.balanceOf(address(tokenWrapper)), 0, "Wrapper should not retain underlying after deposit");
        assertEq(underlying.allowance(address(tokenWrapper), address(pool)), type(uint256).max, "Deposit should still have max allowance");
    }

    function test_migrationImplementation_restoresPoolAllowanceAfterBrokenState() public {
        uint256 skimAmount = 1 ether;
        uint256 depositAmount = 2 ether;

        underlying.mint(address(tokenWrapper), skimAmount);

        vm.startPrank(address(tokenWrapper));
        underlying.approve(address(pool), skimAmount);
        pool.supply(address(underlying), skimAmount, address(tokenWrapper), 0);
        vm.stopPrank();

        assertEq(underlying.allowance(address(tokenWrapper), address(pool)), 0, "Broken V1 state should leave zero allowance");

        address evc = makeAddr("evc-migration");
        MockCollateralVaultFactoryUnit collateralVaultFactory = new MockCollateralVaultFactoryUnit(evc);
        AaveV3ATokenWrapperMigration migrationImplementation = new AaveV3ATokenWrapperMigration(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-migration"))
        );
        AaveV3ATokenWrapper finalImplementation = new AaveV3ATokenWrapper(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-final"))
        );

        tokenWrapper.upgradeToAndCall(
            address(migrationImplementation),
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (address(finalImplementation)))
        );

        assertEq(underlying.allowance(address(tokenWrapper), address(pool)), type(uint256).max, "V2 migration should restore max allowance");
        assertEq(tokenWrapper.version(), 2, "Proxy should end on the clean V2 implementation");

        underlying.mint(bob, depositAmount);
        vm.startPrank(bob);
        underlying.approve(address(tokenWrapper), depositAmount);
        uint256 mintedShares = tokenWrapper.deposit(depositAmount, bob);
        vm.stopPrank();

        assertEq(mintedShares, depositAmount, "Deposit should work again after allowance repair");
    }

    function test_migrationImplementation_revertsWhenFinalImplementationIsMigrator() public {
        address evc = makeAddr("evc-migration-self");
        MockCollateralVaultFactoryUnit collateralVaultFactory = new MockCollateralVaultFactoryUnit(evc);
        AaveV3ATokenWrapperMigration migrationImplementation = new AaveV3ATokenWrapperMigration(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-migration-self"))
        );

        vm.expectRevert(MigrationImplementationCannotBeFinal.selector);
        tokenWrapper.upgradeToAndCall(
            address(migrationImplementation),
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (address(migrationImplementation)))
        );
    }

    function test_migrationImplementation_revertsWhenFinalImplementationVersionIsWrong() public {
        address evc = makeAddr("evc-migration-v3");
        MockCollateralVaultFactoryUnit collateralVaultFactory = new MockCollateralVaultFactoryUnit(evc);
        AaveV3ATokenWrapperMigration migrationImplementation = new AaveV3ATokenWrapperMigration(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-migration-v3"))
        );
        AaveV3ATokenWrapperV3Mock finalImplementation = new AaveV3ATokenWrapperV3Mock(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-final-v3"))
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidFinalImplementationVersion.selector, 3));
        tokenWrapper.upgradeToAndCall(
            address(migrationImplementation),
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (address(finalImplementation)))
        );
    }

    function test_migrationImplementation_revertsWhenFinalImplementationFactoryIsWrong() public {
        address migrationEvc = makeAddr("evc-migration-factory");
        MockCollateralVaultFactoryUnit migrationFactory = new MockCollateralVaultFactoryUnit(migrationEvc);
        AaveV3ATokenWrapperMigration migrationImplementation = new AaveV3ATokenWrapperMigration(
            migrationEvc,
            address(migrationFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-migration-factory"))
        );

        address finalEvc = makeAddr("evc-final-factory");
        MockCollateralVaultFactoryUnit finalFactory = new MockCollateralVaultFactoryUnit(finalEvc);
        AaveV3ATokenWrapper finalImplementation = new AaveV3ATokenWrapper(
            finalEvc,
            address(finalFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-final-factory"))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidFinalImplementationCollateralVaultFactory.selector,
                address(finalFactory)
            )
        );
        tokenWrapper.upgradeToAndCall(
            address(migrationImplementation),
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (address(finalImplementation)))
        );
    }

    function test_migrationImplementation_revertsWhenFinalImplementationEVCIsWrong() public {
        address evc = makeAddr("evc-migration-evc");
        MockCollateralVaultFactoryUnit collateralVaultFactory = new MockCollateralVaultFactoryUnit(evc);
        AaveV3ATokenWrapperMigration migrationImplementation = new AaveV3ATokenWrapperMigration(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-migration-evc"))
        );
        AaveV3ATokenWrapperWrongEVCMock finalImplementation = new AaveV3ATokenWrapperWrongEVCMock(
            evc,
            address(collateralVaultFactory),
            IPool(address(pool)),
            IRewardsController(makeAddr("rewardsController-final-evc")),
            makeAddr("fake-evc")
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidFinalImplementationEVC.selector,
                makeAddr("fake-evc")
            )
        );
        tokenWrapper.upgradeToAndCall(
            address(migrationImplementation),
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (address(finalImplementation)))
        );
    }
}
