// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AaveV3ATokenWrapper} from "../src/AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool as IAaveV3Pool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AToken} from "aave-v3/protocol/tokenization/AToken.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICollateralVaultFactory {
    function EVC() external view returns (address);
    function owner() external view returns (address);
}

contract DeployAaveV3ATokenWrapper is Script {
    // Chain-specific addresses
    address aavePool;
    address ptToken = 0x9Bf45ab47747F4B4dD09B3C2c73953484b4eB375;

    error UnknownProfile();

    function run() external returns (address proxy, address implementation) {
        // Set chain-specific addresses
        if (block.chainid == 1) {
            // Ethereum Mainnet
            aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        } else if (block.chainid == 8453) {
            // Base
            aavePool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
            revert("only mainnet");
        } else {
            revert UnknownProfile();
        }

        console.log("Deploying on chain:", block.chainid);
        console.log("Aave Pool:", aavePool);
        console.log("PT Token:", ptToken);

        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        string memory addressesJson = vm.readFile("TwyneAddresses_output.json");
        address collateralVaultFactory = vm.parseJsonAddress(addressesJson, ".collateralVaultFactory");
        address SAFE = ICollateralVaultFactory(collateralVaultFactory).owner();

        address evc = ICollateralVaultFactory(collateralVaultFactory).EVC();

        // Fetch PT token aToken address dynamically from Aave protocol
        IAaveV3Pool aavePoolContract = IAaveV3Pool(aavePool);
        address ptAToken = aavePoolContract.getReserveData(ptToken).aTokenAddress;
        console.log("PT aToken fetched from Aave:", ptAToken);

        // Validate that the aToken has the correct underlying asset
        require(IAToken(ptAToken).UNDERLYING_ASSET_ADDRESS() == ptToken, "underlying asset not correct");
        console.log("aToken validation: underlying asset matches PT token");

        vm.startBroadcast(deployer);

        implementation = address(new AaveV3ATokenWrapper(
            evc,
            collateralVaultFactory,
            aavePoolContract,
            IRewardsController(address(AToken(ptAToken).REWARDS_CONTROLLER()))
        ));

        string memory aTokenName = IERC20Metadata(ptAToken).name();
        string memory aTokenSymbol = IERC20Metadata(ptAToken).symbol();
        string memory wrapperName = string.concat("Wrapped ", aTokenName);
        string memory wrapperSymbol = string.concat("w", aTokenSymbol);

        console.log("Wrapper name:", wrapperName);
        console.log("Wrapper symbol:", wrapperSymbol);

        bytes memory initData = abi.encodeCall(
            AaveV3ATokenWrapper.initialize,
            (ptAToken, SAFE, wrapperName, wrapperSymbol)
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