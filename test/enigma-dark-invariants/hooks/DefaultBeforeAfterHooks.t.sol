// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title DefaultBeforeAfterHooks
/// @notice Helper contract for before and after hooks, state variable caching and postconditions
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct DefaultVars {
        // 4626
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 exchangeRate;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    DefaultVars defaultVarsBefore;
    DefaultVars defaultVarsAfter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    /// @notice Helper to initialize storage arrays of default vars
    function _setUpDefaultVars(DefaultVars storage _defaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore() internal {
        // Default values
        _setDefaultValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Default values
        _setDefaultValues(defaultVarsAfter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setDefaultValues(DefaultVars storage _defaultVars) internal {
        _defaultVars.totalAssets = aaveV3ATokenWrapper.totalAssets();
        _defaultVars.totalSupply = aaveV3ATokenWrapper.totalSupply();
        _defaultVars.exchangeRate = aavePool.getReserveNormalizedIncome(address(weth));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                POST CONDITIONS: ERC4626                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice DISABLED: Same root cause as INV_ATOKEN_B - aToken deposit rounding mismatch
    /// @dev See BaseInvariants.t.sol:50-61 for details
    function assert_GPOST_ERC4626() internal {
        assertGe(defaultVarsAfter.exchangeRate, defaultVarsBefore.exchangeRate, GPOST_ERC4626_A);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
