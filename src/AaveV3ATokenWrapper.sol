// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {ERC20PermitUpgradeable, ERC20AaveLMUpgradeable, IRewardsController, ERC4626StataTokenUpgradeable, PausableUpgradeable, IStataTokenV2, ERC4626Upgradeable, IPool as IAaveV3Pool, Math, IERC20Permit, ERC20Upgradeable} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {OwnableUpgradeable, ContextUpgradeable} from "lib/aave-v3-origin/lib/solidity-utils/lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC20}  from "lib/aave-v3-origin/lib/solidity-utils/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICollateralVaultFactory {
    function isCollateralVault(address) external view returns (bool);
}
/// @title AaveV3ATokenWrapper
/// @notice ERC4626 wrapper for Aave V3 aTokens to convert rebasing tokens to non-rebasing shares
/// @dev This wrapper allows collateral vaults to hold non-rebasing shares while the underlying aTokens rebase
/// @dev Collateral vaults can pull/push aTokens for direct borrowing from Aave
contract AaveV3ATokenWrapper is
    ERC20PermitUpgradeable,
    ERC20AaveLMUpgradeable,
    ERC4626StataTokenUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    EVCUtil
{
    ICollateralVaultFactory public immutable collateralVaultFactory;

    address internal constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    constructor(
        address _evc,
        address _collateralVaultFactory,
        IAaveV3Pool _aavePool,
        IRewardsController rewardsController
    )
        EVCUtil(_evc)
        ERC20AaveLMUpgradeable(rewardsController)
        ERC4626StataTokenUpgradeable(_aavePool)
    {
        collateralVaultFactory = ICollateralVaultFactory(_collateralVaultFactory);
    }


    function _msgSender() internal view override(ContextUpgradeable, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }

    function initialize(
        address aToken,
        address owner,
        string calldata staticATokenName,
        string calldata staticATokenSymbol
    ) external initializer {
        __ERC20_init(staticATokenName, staticATokenSymbol);
        __ERC20Permit_init(staticATokenName);
        __ERC20AaveLM_init(aToken);
        __ERC4626StataToken_init(aToken);
        __Pausable_init();
        __Ownable_init(owner);
    }

    function setPaused(bool paused) external onlyOwner {
        if (paused) _pause();
        else _unpause();
    }

    function decimals()
        public
        view
        override(ERC20Upgradeable, ERC4626Upgradeable)
        returns (uint8)
    {
        /// @notice The initialization of ERC4626Upgradeable already assures that decimal are
        /// the same as the underlying asset of the StataTokenV2, e.g. decimals of WETH for stataWETH
        return ERC4626Upgradeable.decimals();
    }

    function _claimRewardsOnBehalf(
        address onBehalfOf,
        address receiver,
        address[] memory rewards
    ) internal virtual override whenNotPaused {
        super._claimRewardsOnBehalf(onBehalfOf, receiver, rewards);
    }

    // @notice to merge inheritance with ERC20AaveLMUpgradeable.sol properly we put
    // `whenNotPaused` here instead of using ERC20PausableUpgradeable
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20AaveLMUpgradeable, ERC20Upgradeable) whenNotPaused {
        ERC20AaveLMUpgradeable._update(from, to, amount);
    }

    /// @notice Allows collateral vaults to adjust their aTokens corresponding to totalAssetsDepositedOrReserved
    /// @dev This does NOT affect totalAsset() as aTokens are just moved, not withdrawn
    /// @param shares Amount of shares equivalent to which collateral vault should have aToken balance
    function rebalanceATokens(uint shares) external {
        require(collateralVaultFactory.isCollateralVault(msg.sender), "not collateral vault");

        IERC20 _aToken = IERC20(aToken());
        uint expectedATokenAmount = previewRedeem(shares);
        uint actualATokenAmount = _aToken.balanceOf(msg.sender);

        if (expectedATokenAmount < actualATokenAmount) {
            _aToken.transfer(msg.sender, actualATokenAmount - expectedATokenAmount);
        } else {
            _aToken.transferFrom(msg.sender, address(this), expectedATokenAmount - actualATokenAmount);
        }
    }

    function burnShares(uint assets) external {
        require(collateralVaultFactory.isCollateralVault(msg.sender), "not collateral vault");

        uint shares = _convertToShares(assets, Math.Rounding.Ceil);
        _burn(msg.sender, shares);
    }
}