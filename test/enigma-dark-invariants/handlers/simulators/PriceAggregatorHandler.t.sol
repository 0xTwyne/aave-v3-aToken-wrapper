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

    function setLatestAnswer(uint256 _price, uint8 i) external {
        require(_price < uint256(type(int256).max) && _price > 0, "Price must be less than int256.max and greater than 0");

        // Get a random price aggregator
        address priceAggregator = _getRandomPriceAggregator(i);

        MockAggregatorSetPrice(priceAggregator).setLatestAnswer(int256(_price));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
