// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SETUP                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Initializer for the hooks
    function _setUpHooks() internal {
        _setUpDefaultHooks();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HOOKS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Before hook for the handlers
    function _before() internal {
        _defaultHooksBefore();
    }

    /// @notice After hook for the handlers
    function _after() internal {
        _defaultHooksAfter();

        // POST-CONDITIONS
        _checkPostConditions();

        // Reset the state
        _resetState();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POSTCONDITION CHECKS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Postconditions for the handlers
    function _checkPostConditions() internal {
        // ERC4626
        assert_GPOST_ERC4626();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Resets the state of the handlers
    function _resetState() internal {
        // Implement reset state here
    }
}
