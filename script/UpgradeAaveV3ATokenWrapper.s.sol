// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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

    function run(address proxyAddress) external returns (address newImplementation) {
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

        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");

        address evc = ICollateralVaultFactory(collateralVaultFactory).EVC();

        // Fetch WSTETH aToken address dynamically from Aave protocol
        IAaveV3Pool aavePoolContract = IAaveV3Pool(aavePool);
        address wstethAToken = aavePoolContract.getReserveData(wsteth).aTokenAddress;
        console.log("WSTETH aToken fetched from Aave:", wstethAToken);

        // Validate that the aToken has the correct underlying asset
        require(IAToken(wstethAToken).UNDERLYING_ASSET_ADDRESS() == wsteth, "underlying asset not correct");
        console.log("aToken validation: underlying asset matches WSTETH");

        vm.startBroadcast(deployer);

        newImplementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            aavePoolContract,
            IRewardsController(address(AToken(wstethAToken).REWARDS_CONTROLLER()))
        ));

        AaveV3ATokenWrapper proxy = AaveV3ATokenWrapper(proxyAddress);
        proxy.upgradeToAndCall(newImplementation, "");

        vm.stopBroadcast();

        logUpgrade(proxyAddress, newImplementation, evc, collateralVaultFactory);

        return newImplementation;
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