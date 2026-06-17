// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import Handler contracts,
import {AaveV3ATokenWrapperHandler} from "./handlers/AaveV3ATokenWrapperHandler.t.sol";
import {ERC4626Handler} from "./handlers/ERC4626Handler.t.sol";
import {AavePoolHandler} from "./handlers/AavePoolHandler.t.sol";
import {PriceAggregatorHandler} from "./handlers/simulators/PriceAggregatorHandler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    AaveV3ATokenWrapperHandler,
    ERC4626Handler,
    AavePoolHandler,
    PriceAggregatorHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {}
}
