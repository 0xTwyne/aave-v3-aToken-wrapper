// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";

interface ICollateralVaultFactory {
    function EVC() external view returns (address);
}

contract DeployAaveV3ATokenWrapper is Script {
    // Mainnet addresses
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WSTETH_ATOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    function run() external returns (address proxy, address implementation) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address SAFE = vm.envAddress("ADMIN_ETH_ADDRESS");

        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");

        address evc = ICollateralVaultFactory(collateralVaultFactory).EVC();

        vm.startBroadcast(deployer);

        implementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            IAaveV3Pool(AAVE_POOL),
            IRewardsController(address(AToken(WSTETH_ATOKEN).REWARDS_CONTROLLER()))
        ));

        bytes memory initData = abi.encodeCall(
            AaveV3ATokenWrapper.initialize,
            (WSTETH_ATOKEN, SAFE, "Wrapped stataWSTETH", "wstataWSTETH")
        );

        proxy = address(new ERC1967Proxy(implementation, initData));

        vm.stopBroadcast();

        logDeployment(proxy, implementation, evc, collateralVaultFactory, SAFE);

        return (proxy, implementation);
    }

    function logDeployment(
        address proxy,
        address implementation,
        address evc,
        address collateralVaultFactory,
        address owner
    ) internal pure {
        console.log("===== AaveV3ATokenWrapper Deployment Complete =====");
        console.log("Proxy Address:", proxy);
        console.log("Implementation Address:", implementation);
        console.log("EVC Address:", evc);
        console.log("Collateral Vault Factory:", collateralVaultFactory);
        console.log("Owner:", owner);
        console.log("====================================");
    }
}