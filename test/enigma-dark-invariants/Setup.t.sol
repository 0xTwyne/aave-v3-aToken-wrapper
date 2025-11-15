// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

// Libraries
import {TestnetERC20} from "aave-v3/mocks/testnet-helpers/TestnetERC20.sol";
import {
    AaveV3BatchOrchestration,
    MarketReport
} from "aave-v3-origin/src/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol";
import {Create2Utils} from "aave-v3-origin/src/deployments/contracts/utilities/Create2Utils.sol";

// Contracts
import {Actor} from "./utils/Actor.sol";
import {BaseTest} from "./base/BaseTest.t.sol";
import {
    Roles,
    MarketConfig,
    DeployFlags,
    ContractsReport
} from "aave-v3-origin/src/deployments/interfaces/IMarketReportTypes.sol";
import {AaveV3TestListing, IEngine} from "aave-v3-origin/tests/mocks/AaveV3TestListing.sol";
import {MockCollateralVaultFactory} from "test/AaveV3ATokenWrapper.t.sol";
import {AaveV3ATokenWrapper} from "src/AaveV3ATokenWrapper.sol";
import {PullRewardsTransferStrategy} from "aave-v3/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MarketReportUtils} from "aave-v3-origin/src/deployments/contracts/utilities/MarketReportUtils.sol";
import {Create2Factory} from "aave-v3-origin/tests/invariants/utils/Create2Factory.sol";
import {ACLManager} from "aave-v3-origin/src/contracts/protocol/configuration/ACLManager.sol";
import {MockAggregatorSetPrice} from "./utils/mocks/MockAggregatorSetPrice.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    using MarketReportUtils for MarketReport;

    /// @notice Number of actors to deploy
    function _setUp() internal {
        // Set admin address
        admin = address(this);
        emissionAdmin = address(this);

        // Deploy the suite assets
        _deployAssets();

        // Deploy protocol contracts and protocol actors
        _deployProtocolCore();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          CORE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        /// Deployment parameters
        Roles memory roles = Roles({marketOwner: admin, poolAdmin: admin, emergencyAdmin: admin});

        MarketConfig memory config;
        config.marketId = "Aave V3 Test Market";
        config.providerId = 8080;
        config.oracleDecimals = 8;
        config.flashLoanPremium = 0.0005e4;

        DeployFlags memory flags;
        MarketReport memory deployedContracts;

        config.wrappedNativeToken = address(weth);

        // Deploy protocol core
        MarketReport memory r = AaveV3BatchOrchestration.deployAaveV3(admin, roles, config, flags, deployedContracts);
        AaveV3TestListing testnetListingPayload =
            new AaveV3TestListing(IEngine(r.configEngine), roles.poolAdmin, address(weth), r);
        ACLManager manager = ACLManager(r.aclManager);
        manager.addPoolAdmin(address(testnetListingPayload));
        testnetListingPayload.execute();

        // Get contracts report
        ContractsReport memory contracts = r.toContractsReport();

        // Set mock USDC asset
        usdc = TestnetERC20(address(testnetListingPayload.USDX_ADDRESS()));
        baseAssets.push(address(usdc));
        vm.label(address(usdc), "USDC");

        // Set extended price aggregators
        priceAggregatorUSDC = address(new MockAggregatorSetPrice(1e6));
        priceAggregatorWETH = address(new MockAggregatorSetPrice(1800e8));

        priceAggregators = [priceAggregatorUSDC, priceAggregatorWETH];

        address[] memory assets = new address[](2);
        assets[0] = address(usdc);
        assets[1] = address(weth);

        address[] memory sources = new address[](2);
        sources[0] = priceAggregatorUSDC;
        sources[1] = priceAggregatorWETH;

        contracts.aaveOracle.setAssetSources(assets, sources);

        // Set Aave V3 contracts
        aavePool = IPool(address(r.poolProxy));
        vm.label(address(aavePool), "Aave Pool");
        aToken = IAToken(aavePool.getReserveData(address(weth)).aTokenAddress);
        vm.label(address(aToken), "A-Token");
        require(IAToken(aToken).UNDERLYING_ASSET_ADDRESS() == address(weth), "underlying asset not correct");

        address evc = address(new EthereumVaultConnector());
        vm.label(evc, "EVC");

        collateralVaultFactory = new MockCollateralVaultFactory(evc);
        vm.label(address(collateralVaultFactory), "Collateral Vault Factory");
        collateralVaultFactory.setIsCollateralVault(collateralVault, true);
        vm.label(collateralVault, "Collateral Vault");

        // Deploy implementation
        address implementation = address(
            new AaveV3ATokenWrapper(
                evc,
                address(collateralVaultFactory),
                aavePool,
                contracts.rewardsControllerProxy // Use the one from TestnetProcedures
            )
        );
        vm.label(implementation, "AaveV3ATokenWrapper Implementation");

        // Encode initialization data
        bytes memory initData =
            abi.encodeCall(aaveV3ATokenWrapper.initialize, (address(aToken), address(this), "A-Stat-WETH", "asWETH"));

        // Deploy proxy
        address proxy = address(new ERC1967Proxy(implementation, initData));
        aaveV3ATokenWrapper = AaveV3ATokenWrapper(proxy);
        vm.label(address(aaveV3ATokenWrapper), "AaveV3ATokenWrapper");

        // Approve aaveV3ATokenWrapper to spend weth on collateral vault
        vm.prank(collateralVault);
        weth.approve(address(aaveV3ATokenWrapper), type(uint256).max);

        // Setup reward token and strategy
        strategy = new PullRewardsTransferStrategy(r.rewardsControllerProxy, emissionAdmin, emissionAdmin);
        vm.label(address(strategy), "PullRewardsTransferStrategy");

        vm.prank(admin);
        contracts.emissionManager.setEmissionAdmin(rewardToken, emissionAdmin);
        vm.label(address(contracts.emissionManager), "Emission Manager");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ASSETS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy the suite assets
    function _deployAssets() internal {
        // Deploy the suite assets
        weth = new TestnetERC20("Test Token", "WETH", 18, admin);
        baseAssets.push(address(weth));
        vm.label(address(weth), "WETH");

        rewardToken = address(new TestnetERC20("LM Reward ERC20", "RWD", 18, admin));
        vm.label(rewardToken, "Reward Token");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTORS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](3);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);
        tokens[2] = address(aToken);

        address[] memory contracts = new address[](2);
        contracts[0] = address(aavePool);
        contracts[1] = address(aaveV3ATokenWrapper);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deploy actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, contracts);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                if (tokens[j] != address(aToken)) {
                    TestnetERC20 _token = TestnetERC20(tokens[j]);
                    _token.mint(_actor, INITIAL_BALANCE);
                }
            }
            actorAddresses.push(_actor);
            vm.label(_actor, string(abi.encodePacked("Actor ", i)));
        }
    }

    /// @notice Deploy an actor proxy contract for a user address
    /// @param userAddress Address of the user
    /// @param tokens Array of token addresses
    /// @param contracts Array of contract addresses to aprove tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(address userAddress, address[] memory tokens, address[] memory contracts)
        internal
        returns (address actorAddress)
    {
        bool success;
        Actor _actor = new Actor(tokens, contracts);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }

    function _etchCreate2Factory() internal virtual {
        // Etch the create2 factory
        vm.etch(Create2Utils.CREATE2_FACTORY, type(Create2Factory).runtimeCode);
    }
}
