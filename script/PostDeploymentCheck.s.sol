// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICollateralVaultFactory} from "../src/AaveV3ATokenWrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

/// @title PostDeploymentCheck
/// @notice Comprehensive post-deployment verification for AaveV3ATokenWrapper
contract PostDeploymentCheck is Script {
    // Contract instances
    AaveV3ATokenWrapper public wrapper;
    address public collateralVaultFactory;
    address public evc;
    
    // Expected addresses
    address public expectedAdmin;
    address public expectedAToken;
    address public expectedAavePool;
    
    error CheckFailed(string reason);
    
    function run(address proxyAddress) external {
        // Load configuration
        loadConfiguration();
        
        // Initialize wrapper instance
        wrapper = AaveV3ATokenWrapper(proxyAddress);
        
        // Run all checks
        runAllChecks();
        
        console.log("\n========================================");
        console.log("All post-deployment checks passed successfully!");
        console.log("========================================\n");
    }
    
    function loadConfiguration() internal {
        // Load addresses from JSON
        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");
        
        // Get EVC from factory
        evc = ICollateralVaultFactory(collateralVaultFactory).EVC();
        
        // Load expected values from environment
        expectedAdmin = vm.envAddress("ADMIN_ETH_ADDRESS");
        
        // Set expected mainnet addresses
        if (block.chainid == 1) {
            expectedAToken = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371; // aWSTETH
            expectedAavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        } else if (block.chainid == 8453) { // Base
            // Update these with Base-specific addresses when available
            revert CheckFailed("Base addresses not configured");
        } else {
            revert CheckFailed("Unsupported chain");
        }
        
        console.log("Configuration loaded:");
        console.log("  Chain ID:", block.chainid);
        console.log("  Expected Admin:", expectedAdmin);
        console.log("  Collateral Vault Factory:", collateralVaultFactory);
        console.log("  EVC:", evc);
    }
    
    function runAllChecks() internal {
        console.log("\nRunning post-deployment checks...\n");
        
        checkProxyDeployment();
        checkInitialization();
        checkOwnership();
        checkCollateralVaultFactory();
        checkEVC();
        checkAaveIntegration();
        checkERC4626Compliance();
        checkPausability();
        checkUpgradeability();
        checkAccessControl();
    }
    
    /// @notice Verify proxy is properly deployed
    function checkProxyDeployment() internal view {
        console.log("Checking proxy deployment...");
        
        // Check proxy has code
        require(address(wrapper).code.length > 0, "Proxy has no code");
        
        // Check it's actually a proxy (has minimal code size typical of proxies)
        require(address(wrapper).code.length < 500, "Not a proxy contract");
        
        console.log("  [PASS] Proxy deployed correctly");
    }
    
    /// @notice Verify contract initialization
    function checkInitialization() internal view {
        console.log("Checking initialization...");
        
        // Check name and symbol are set
        string memory name = wrapper.name();
        string memory symbol = wrapper.symbol();
        require(bytes(name).length > 0, "Name not set");
        require(bytes(symbol).length > 0, "Symbol not set");
        
        // Check decimals
        require(wrapper.decimals() == 18, "Incorrect decimals");
        
        // Check underlying asset
        address underlying = wrapper.asset();
        require(underlying != address(0), "Underlying asset not set");
        
        console.log("  [PASS] Contract initialized");
        console.log("    Name:", name);
        console.log("    Symbol:", symbol);
        console.log("    Underlying:", underlying);
    }
    
    /// @notice Verify ownership configuration
    function checkOwnership() internal view {
        console.log("Checking ownership...");
        
        address owner = wrapper.owner();
        require(owner != address(0), "Owner is zero address");
        require(owner == expectedAdmin, "Owner mismatch");
        
        console.log("  [PASS] Owner correctly set to:", owner);
    }
    
    /// @notice Verify collateral vault factory integration
    function checkCollateralVaultFactory() internal view {
        console.log("Checking collateral vault factory...");
        
        address factoryFromWrapper = address(wrapper.collateralVaultFactory());
        require(factoryFromWrapper != address(0), "Factory not set");
        require(factoryFromWrapper == collateralVaultFactory, "Factory mismatch");
        
        // Verify factory has code
        require(factoryFromWrapper.code.length > 0, "Factory has no code");
        
        console.log("  [PASS] Collateral vault factory integrated:", factoryFromWrapper);
    }
    
    /// @notice Verify EVC integration
    function checkEVC() internal view {
        console.log("Checking EVC integration...");
        
        // Check EVC from factory matches expected
        address evcFromFactory = ICollateralVaultFactory(collateralVaultFactory).EVC();
        require(evcFromFactory == evc, "EVC mismatch");
        require(evcFromFactory != address(0), "EVC is zero address");
        
        // Verify EVC has code
        require(evcFromFactory.code.length > 0, "EVC has no code");
        
        console.log("  [PASS] EVC correctly integrated:", evcFromFactory);
    }
    
    /// @notice Verify Aave protocol integration
    function checkAaveIntegration() internal view {
        console.log("Checking Aave integration...");
        
        // Check aToken
        address aToken = wrapper.aToken();
        require(aToken != address(0), "aToken not set");
        require(aToken == expectedAToken, "aToken mismatch");
        
        // Check Aave pool
        address aavePool = address(wrapper.POOL());
        require(aavePool != address(0), "Aave pool not set");
        require(aavePool == expectedAavePool, "Aave pool mismatch");
        
        // Check rewards controller
        address rewardsController = address(wrapper.INCENTIVES_CONTROLLER());
        require(rewardsController != address(0), "Rewards controller not set");
        
        // Verify aToken is valid
        require(aToken.code.length > 0, "aToken has no code");
        
        console.log("  [PASS] Aave integration verified");
        console.log("    aToken:", aToken);
        console.log("    Aave Pool:", aavePool);
        console.log("    Rewards Controller:", rewardsController);
    }
    
    /// @notice Verify ERC4626 compliance
    function checkERC4626Compliance() internal view {
        console.log("Checking ERC4626 compliance...");
        
        // Check maxDeposit
        uint256 maxDep = wrapper.maxDeposit(address(this));
        require(maxDep > 0, "maxDeposit returns 0");
        
        // Check maxMint
        uint256 maxMnt = wrapper.maxMint(address(this));
        require(maxMnt > 0, "maxMint returns 0");
        
        // Check totalAssets can be called
        wrapper.totalAssets();
        
        // Check conversion functions
        wrapper.convertToShares(1e18);
        wrapper.convertToAssets(1e18);
        
        console.log("  [PASS] ERC4626 functions operational");
    }
    
    /// @notice Verify pausability functions
    function checkPausability() internal view {
        console.log("Checking pausability...");
        
        bool paused = wrapper.paused();
        require(!paused, "Contract is paused");
        
        console.log("  [PASS] Contract is not paused");
    }
    
    /// @notice Verify upgradeability configuration
    function checkUpgradeability() internal view {
        console.log("Checking upgradeability...");
        
        // Check version
        uint256 version = wrapper.version();
        require(version == 1, "Unexpected version");
        
        // Note: We can't check the actual upgrade function without being owner,
        // but we can verify the version is as expected
        
        console.log("  [PASS] Version is:", version);
    }
    
    /// @notice Verify access control for CV functions
    function checkAccessControl() internal {
        console.log("Checking access control...");
        
        // Try to call CV functions - should revert since this script is not a collateral vault
        address testUser = makeAddr("testUser");
        vm.startPrank(testUser);
        
        // Test rebalanceATokens_CV should revert
        try wrapper.rebalanceATokens_CV(1e18) {
            revert CheckFailed("rebalanceATokens_CV should revert for non-CV");
        } catch {
            // Expected to revert
        }
        
        // Test burnShares_CV should revert
        try wrapper.burnShares_CV(1e18) {
            revert CheckFailed("burnShares_CV should revert for non-CV");
        } catch {
            // Expected to revert
        }
        
        vm.stopPrank();
        
        console.log("  [PASS] Access control working correctly");
    }
}