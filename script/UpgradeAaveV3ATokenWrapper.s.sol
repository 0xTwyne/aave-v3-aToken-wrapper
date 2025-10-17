// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";

interface ICollateralVaultFactory {
    function EVC() external view returns (address);
}

contract UpgradeAaveV3ATokenWrapper is Script {
    // Mainnet addresses
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WSTETH_ATOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    function run(address proxyAddress) external returns (address newImplementation) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");

        address evc = ICollateralVaultFactory(collateralVaultFactory).EVC();

        vm.startBroadcast(deployer);

        newImplementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            IAaveV3Pool(AAVE_POOL),
            IRewardsController(address(AToken(WSTETH_ATOKEN).REWARDS_CONTROLLER()))
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