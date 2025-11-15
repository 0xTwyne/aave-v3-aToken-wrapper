// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {BaseHandler} from "../../base/BaseHandler.t.sol";
import {MockAggregatorSetPrice} from "../../utils/mocks/MockAggregatorSetPrice.sol";

/// @title PriceAggregatorHandler
/// @notice Handler test contract for a set of actions
contract PriceAggregatorHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setLatestAnswer(int256 _price, uint8 i) external {
        // Get a random price aggregator
        address priceAggregator = _getRandomPriceAggregator(i);

        MockAggregatorSetPrice(priceAggregator).setLatestAnswer(_price);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
