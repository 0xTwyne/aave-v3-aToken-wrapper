// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IPool} from "aave-v3/interfaces/IPool.sol";

// Test Contracts
import {Actor} from "test/enigma-dark-invariants/utils/Actor.sol";
import {BaseHandler} from "test/enigma-dark-invariants/base/BaseHandler.t.sol";
import {IAavePoolHandler} from "test/enigma-dark-invariants/handlers/interfaces/IAavePoolHandler.sol";

/// @title AavePoolHandler
/// @notice Handler test contract for the Aave liquidation actions
abstract contract AavePoolHandler is BaseHandler, IAavePoolHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function aave_supply(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address asset = _getRandomBaseAsset(i);

        _before();
        (success, returnData) =
            actor.proxy(address(aavePool), abi.encodeCall(IPool.supply, (asset, amount, address(actor), 0)));

        if (success) {
            _after();
        } else {
            revert("AavePoolHandler: supply failed");
        }
    }

    function aave_withdraw(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address asset = _getRandomBaseAsset(i);

        _before();
        (success, returnData) =
            actor.proxy(address(aavePool), abi.encodeCall(IPool.withdraw, (asset, amount, address(actor))));

        if (success) {
            _after();
        } else {
            revert("AavePoolHandler: withdraw failed");
        }
    }

    function aave_borrow(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address asset = _getRandomBaseAsset(i);

        _before();
        (success, returnData) =
            actor.proxy(address(aavePool), abi.encodeCall(IPool.borrow, (asset, amount, 2, 0, address(actor))));

        if (success) {
            _after();
        } else {
            revert("AavePoolHandler: borrow failed");
        }
    }

    function aave_repay(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address asset = _getRandomBaseAsset(i);

        _before();
        (success, returnData) =
            actor.proxy(address(aavePool), abi.encodeCall(IPool.repay, (asset, amount, 2, address(actor))));

        if (success) {
            _after();
        } else {
            revert("AavePoolHandler: repay failed");
        }
    }

    /// @notice Liquidates an actor's debt
    function aave_liquidateActor(uint256 debtToCover, bool receiveAToken, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address violator = _getRandomActor(i);

        address collateralAsset = _getRandomBaseAsset(j);
        address debtAsset = _getRandomBaseAsset(k);

        _before();
        (success, returnData) = actor.proxy(
            address(aavePool),
            abi.encodeCall(IPool.liquidationCall, (collateralAsset, debtAsset, violator, debtToCover, receiveAToken))
        );

        if (success) {
            _after();
        } else {
            revert("AavePoolHandler: liquidateActor failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        OWNER ACTIONS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // TODO select which functions to include
}
