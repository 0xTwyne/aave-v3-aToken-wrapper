// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {AaveV3ATokenWrapper} from "./AaveV3ATokenWrapper.sol";
import {IRewardsController, IPool} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";

error UUPSUnsupportedProxiableUUID(bytes32 slot);
error InvalidFinalImplementationVersion(uint256 version);
error InvalidFinalImplementationCollateralVaultFactory(address collateralVaultFactory);
error InvalidFinalImplementationEVC(address evc);
error MigrationImplementationCannotBeFinal();

/// @notice Temporary implementation used only to migrate broken V1 proxies to clean V2 code
contract AaveV3ATokenWrapperMigration is AaveV3ATokenWrapper {
    constructor(
        address _evc,
        address _collateralVaultFactory,
        IPool _aavePool,
        IRewardsController rewardsController
    ) AaveV3ATokenWrapper(_evc, _collateralVaultFactory, _aavePool, rewardsController) {}

    /// @notice Restores the wrapper's pool allowance and finalizes the proxy onto the clean implementation
    function migrateToFinal(address finalImplementation) external onlyOwner {
        require(finalImplementation != ERC1967Utils.getImplementation(), MigrationImplementationCannotBeFinal());

        SafeERC20.forceApprove(IERC20(asset()), address(POOL), type(uint256).max);

        AaveV3ATokenWrapper finalWrapper = AaveV3ATokenWrapper(finalImplementation);

        uint256 finalVersion = finalWrapper.version();
        require(finalVersion == 2, InvalidFinalImplementationVersion(finalVersion));

        address finalCollateralVaultFactory = address(finalWrapper.collateralVaultFactory());
        require(
            finalCollateralVaultFactory == address(collateralVaultFactory),
            InvalidFinalImplementationCollateralVaultFactory(finalCollateralVaultFactory)
        );

        address finalEVC = finalWrapper.EVC();
        require(finalEVC == address(evc), InvalidFinalImplementationEVC(finalEVC));

        try IERC1822Proxiable(finalImplementation).proxiableUUID() returns (bytes32 slot) {
            require(slot == ERC1967Utils.IMPLEMENTATION_SLOT, UUPSUnsupportedProxiableUUID(slot));
        } catch {
            revert ERC1967Utils.ERC1967InvalidImplementation(finalImplementation);
        }

        ERC1967Utils.upgradeToAndCall(finalImplementation, "");
    }
}
