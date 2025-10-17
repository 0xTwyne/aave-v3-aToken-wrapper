// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {ERC20PermitUpgradeable, ERC20AaveLMUpgradeable, IRewardsController, ERC4626StataTokenUpgradeable, PausableUpgradeable, IStataTokenV2, ERC4626Upgradeable, IPool as IAaveV3Pool, Math, IERC20Permit, ERC20Upgradeable} from "aave-v3/extensions/stata-token/StataTokenV2.sol";
import {OwnableUpgradeable, ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20}  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable}  from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";


interface ICollateralVaultFactory {
    function isCollateralVault(address) external view returns (bool);
}

error NotCollateralVault();

/// @title AaveV3ATokenWrapper
/// @notice ERC4626 wrapper for Aave V3 aTokens to convert rebasing tokens to non-rebasing shares
/// @dev This wrapper allows collateral vaults to hold non-rebasing shares while the underlying aTokens rebase.
/// @dev Collateral vaults can pull/push aTokens for direct borrowing from Aave.
/// @dev This contract is StataTokenV2 + UUPSUpgradeable + 2 custom fns at the end.
contract AaveV3ATokenWrapper is
    ERC20PermitUpgradeable,
    ERC20AaveLMUpgradeable,
    ERC4626StataTokenUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    EVCUtil
{
    ICollateralVaultFactory public immutable collateralVaultFactory;

    uint[50] internal __gap;

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
        _disableInitializers();
    }


    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Only the owner can authorize upgrades (required by UUPSUpgradeable)
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Returns the current implementation version
    /// @return Version string
    function version() external pure virtual returns (uint) {
        return 1;
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
        __UUPSUpgradeable_init();
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

    ///////////// Custom Twyne functions /////////////

    modifier onlyCV {
        require(collateralVaultFactory.isCollateralVault(msg.sender), NotCollateralVault());
        _;
    }

    /// @notice Allows collateral vaults to adjust their aTokens corresponding to totalAssetsDepositedOrReserved
    /// @dev It makes the aToken.scaledBalance(msg.sender) same as `shares`
    /// @param shares Amount of shares equivalent to which collateral vault should have aToken balance
    function rebalanceATokens_CV(uint shares) external onlyCV {
        IAToken _aToken = IAToken(aToken());

        uint actualScaledBalance = _aToken.scaledBalanceOf(msg.sender);

        if (shares < actualScaledBalance) {
            _aToken.transferFrom(msg.sender, address(this), _convertToAssets(actualScaledBalance - shares, Math.Rounding.Floor));
        } else {
            _aToken.transfer(msg.sender, _convertToAssets(shares - actualScaledBalance, Math.Rounding.Floor));
        }
    }

    /// @notice Allows collateral vaults to burn their shares if they are externally liquidated
    /// @dev When a collateral vault is externally liquidated, aTokens are forcefully removed
    ///      from the aTokens transferred from this wrapper to the collateral vault. This wrapper
    ///      needs to burn the corresponding shares since the removed aTokens are no longer a part of
    ///      this wrapper's totalAssets.
    /// @param shares Amount of shares corresponding to aTokens taken away in external liquidation
    function burnShares_CV(uint shares) external onlyCV {
        _burn(msg.sender, shares);
    }
}