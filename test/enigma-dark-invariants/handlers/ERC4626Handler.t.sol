// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC4626Handler} from "test/enigma-dark-invariants/handlers/interfaces/IERC4626Handler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "test/enigma-dark-invariants/utils/Actor.sol";
import {BaseHandler} from "test/enigma-dark-invariants/base/BaseHandler.t.sol";

/// @title ERC4626Handler
/// @notice Handler test contract for a set of actions
contract ERC4626Handler is BaseHandler, IERC4626Handler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 assets) external setup {
        bool success;
        bytes memory returnData;

        _before();
        (success, returnData) =
            actor.proxy(address(aaveV3ATokenWrapper), abi.encodeCall(IERC4626.deposit, (assets, address(actor))));

        if (success) {
            _after();
        } else {
            revert("ERC4626Handler: deposit failed");
        }
    }

    function mint(uint256 shares) external setup {
        bool success;
        bytes memory returnData;

        _before();
        (success, returnData) =
            actor.proxy(address(aaveV3ATokenWrapper), abi.encodeCall(IERC4626.mint, (shares, address(actor))));

        if (success) {
            _after();
        } else {
            revert("ERC4626Handler: mint failed");
        }
    }

    function withdraw(uint256 assets) external setup {
        bool success;
        bytes memory returnData;

        _before();
        (success, returnData) = actor.proxy(
            address(aaveV3ATokenWrapper), abi.encodeCall(IERC4626.withdraw, (assets, address(actor), address(actor)))
        );

        if (success) {
            _after();
        } else {
            revert("ERC4626Handler: withdraw failed");
        }
    }

    function redeem(uint256 shares) external setup {
        bool success;
        bytes memory returnData;

        _before();
        (success, returnData) = actor.proxy(
            address(aaveV3ATokenWrapper), abi.encodeCall(IERC4626.redeem, (shares, address(actor), address(actor)))
        );

        if (success) {
            _after();
        } else {
            revert("ERC4626Handler: redeem failed");
        }
    }

    function transfer(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address recipient = _getRandomActor(i);

        _before();
        (success, returnData) =
            actor.proxy(address(aaveV3ATokenWrapper), abi.encodeCall(IERC20.transfer, (recipient, amount)));

        if (success) {
            _after();
        } else {
            revert("ERC4626Handler: transfer failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
