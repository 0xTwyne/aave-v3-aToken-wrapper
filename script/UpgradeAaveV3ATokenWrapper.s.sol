// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {AaveV3ATokenWrapperMigration} from "../src/AaveV3ATokenWrapperMigration.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

interface ICollateralVaultFactory {
    function EVC() external view returns (address);
}

contract UpgradeAaveV3ATokenWrapper is Script {
    // Chain-specific addresses
    address aavePool;
    address wsteth;

    error UnknownProfile();
    error WrapperFactoryMismatch(address actualFactory);
    error WrapperEVCMismatch(address actualEVC);
    error FactoryEVCMismatch(address actualEVC);

    function run() external returns (address newImplementation) {
        // Set chain-specific addresses
        if (block.chainid == 1) {
            // Ethereum Mainnet
            aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
            wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        } else if (block.chainid == 8453) {
            // Base
            aavePool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
            wsteth = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
        } else {
            revert UnknownProfile();
        }

        console.log("Upgrading on chain:", block.chainid);
        console.log("Aave Pool:", aavePool);
        console.log("WSTETH:", wsteth);

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        string memory addressesJson = vm.readFile(_deploymentAddressesPath());
        address proxyAddress = vm.parseJsonAddress(addressesJson, ".aTokenWrappers.awstETH");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");
        address evc = vm.parseJsonAddress(addressesJson, ".evc");
        AaveV3ATokenWrapper proxy = AaveV3ATokenWrapper(proxyAddress);

        require(
            address(proxy.collateralVaultFactory()) == collateralVaultFactory,
            WrapperFactoryMismatch(address(proxy.collateralVaultFactory()))
        );
        require(proxy.EVC() == evc, WrapperEVCMismatch(proxy.EVC()));
        require(ICollateralVaultFactory(collateralVaultFactory).EVC() == evc, FactoryEVCMismatch(ICollateralVaultFactory(collateralVaultFactory).EVC()));

        // Fetch WSTETH aToken address dynamically from Aave protocol
        IAaveV3Pool aavePoolContract = IAaveV3Pool(aavePool);
        address wstethAToken = aavePoolContract.getReserveData(wsteth).aTokenAddress;
        console.log("WSTETH aToken fetched from Aave:", wstethAToken);

        // Validate that the aToken has the correct underlying asset
        require(IAToken(wstethAToken).UNDERLYING_ASSET_ADDRESS() == wsteth, "underlying asset not correct");
        console.log("aToken validation: underlying asset matches WSTETH");

        vm.startBroadcast(deployer);

        address migrationImplementation = address(new AaveV3ATokenWrapperMigration(
            evc,
            collateralVaultFactory,
            aavePoolContract,
            IRewardsController(address(AToken(wstethAToken).REWARDS_CONTROLLER()))
        ));

        newImplementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            aavePoolContract,
            IRewardsController(address(AToken(wstethAToken).REWARDS_CONTROLLER()))
        ));

        proxy.upgradeToAndCall(
            migrationImplementation,
            abi.encodeCall(AaveV3ATokenWrapperMigration.migrateToFinal, (newImplementation))
        );

        require(
            address(proxy.collateralVaultFactory()) == collateralVaultFactory,
            WrapperFactoryMismatch(address(proxy.collateralVaultFactory()))
        );
        require(proxy.EVC() == evc, WrapperEVCMismatch(proxy.EVC()));

        vm.stopBroadcast();

        logUpgrade(proxyAddress, newImplementation, evc, collateralVaultFactory);

        return newImplementation;
    }

    function _deploymentAddressesPath() internal view returns (string memory) {
        if (block.chainid == 1) {
            return "../tech-notes/public-launch-addresses/TwyneAddresses_current_1.json";
        }
        if (block.chainid == 8453) {
            return "../tech-notes/base-test-addresses/TwyneAddresses_current_8453.json";
        }
        revert UnknownProfile();
    }

    function logUpgrade(
        address proxy,
        address newImplementation,
        address evc,
        address collateralVaultFactory
    ) internal pure {
        console.log("===== AaveV3ATokenWrapper Upgrade Complete =====");
        console.log("Proxy Address:", proxy);
        console.log("New Implementation:", newImplementation);
        console.log("EVC Address:", evc);
        console.log("Collateral Vault Factory:", collateralVaultFactory);
        console.log("=================================");
    }
}
