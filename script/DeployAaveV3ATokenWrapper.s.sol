// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

interface ICollateralVaultFactory {
    function EVC() external view returns (address);
    function owner() external view returns (address);
}

contract DeployAaveV3ATokenWrapper is Script {
    // Chain-specific addresses
    address aavePool;
    address wsteth;

    error UnknownProfile();

    function run() external returns (address proxy, address implementation) {
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

        console.log("Deploying on chain:", block.chainid);
        console.log("Aave Pool:", aavePool);
        console.log("WSTETH:", wsteth);

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");
        address SAFE = ICollateralVaultFactory(collateralVaultFactory).owner();

        address evc = ICollateralVaultFactory(collateralVaultFactory).EVC();

        // Fetch WSTETH aToken address dynamically from Aave protocol
        IAaveV3Pool aavePoolContract = IAaveV3Pool(aavePool);
        address wstethAToken = aavePoolContract.getReserveData(wsteth).aTokenAddress;
        console.log("WSTETH aToken fetched from Aave:", wstethAToken);

        // Validate that the aToken has the correct underlying asset
        require(IAToken(wstethAToken).UNDERLYING_ASSET_ADDRESS() == wsteth, "underlying asset not correct");
        console.log("aToken validation: underlying asset matches WSTETH");

        vm.startBroadcast(deployer);

        implementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            aavePoolContract,
            IRewardsController(address(AToken(wstethAToken).REWARDS_CONTROLLER()))
        ));

        bytes memory initData = abi.encodeCall(
            AaveV3ATokenWrapper.initialize,
            (wstethAToken, SAFE, "Wrapped stataWSTETH", "wstataWSTETH")
        );

        proxy = address(new ERC1967Proxy(implementation, initData));

        vm.stopBroadcast();

        logDeployment(proxy, implementation, evc, collateralVaultFactory, SAFE);
        writeDeploymentToJson(proxy);

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

    function writeDeploymentToJson(
        address proxy
    ) internal {
        string memory chainName = block.chainid == 1 ? "mainnet" : block.chainid == 8453 ? "base" : "unknown";
        string memory fileName = string.concat(chainName, ".json");

        string memory json = "deployment";
        json = vm.serializeAddress(json, "proxy", proxy);

        vm.writeFile(fileName, json);
        console.log("Deployment info written to:", fileName);
    }
}