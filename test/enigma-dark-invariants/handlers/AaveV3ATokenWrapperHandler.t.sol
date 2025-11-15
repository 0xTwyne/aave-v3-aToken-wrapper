// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {
    IAaveV3ATokenWrapperHandler
} from "test/enigma-dark-invariants/handlers/interfaces/IAaveV3ATokenWrapperHandler.sol";
import {IERC4626StataToken} from "aave-v3/extensions/stata-token/interfaces/IERC4626StataToken.sol";

// Libraries
import "forge-std/console.sol";

// Contracts
import {AaveV3ATokenWrapper} from "src/AaveV3ATokenWrapper.sol";

// Test Contracts
import {Actor} from "test/enigma-dark-invariants/utils/Actor.sol";
import {BaseHandler} from "test/enigma-dark-invariants/base/BaseHandler.t.sol";

/// @title AaveV3ATokenWrapperHandler
/// @notice Handler test contract for a set of actions
contract AaveV3ATokenWrapperHandler is BaseHandler, IAaveV3ATokenWrapperHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function depositATokens(uint256 assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address receiver = _getRandomActor(i);

        _before();
        (success, returnData) = actor.proxy(
            address(aaveV3ATokenWrapper), abi.encodeCall(aaveV3ATokenWrapper.depositATokens, (assets, receiver))
        );

        if (success) {
            _after();
        } else {
            revert("AaveV3ATokenWrapperHandler: depositATokens failed");
        }
    }

    function depositWithPermit(uint256 assets, bool depositToAave, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address receiver = _getRandomActor(i);

        _before();
        (success, returnData) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(
                aaveV3ATokenWrapper.depositWithPermit,
                (assets, receiver, 0, IERC4626StataToken.SignatureParams(0, 0, 0), depositToAave)
            )
        );

        if (success) {
            _after();
        } else {
            revert("AaveV3ATokenWrapperHandler: depositWithPermit failed");
        }
    }

    function redeemATokens(uint256 shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address receiver = _getRandomActor(i);

        _before();
        (success, returnData) = actor.proxy(
            address(aaveV3ATokenWrapper),
            abi.encodeCall(aaveV3ATokenWrapper.redeemATokens, (shares, receiver, address(actor)))
        );

        if (success) {
            _after();
        } else {
            revert("AaveV3ATokenWrapperHandler: redeemATokens failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   COLLATERAL VAULT ACTIONS                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function rebalanceATokens_CV(uint256 shares) external {
        vm.prank(collateralVault);
        aaveV3ATokenWrapper.rebalanceATokens_CV(shares);
    }

    function burnShares_CV(uint256 shares) external {
        vm.prank(collateralVault);
        aaveV3ATokenWrapper.burnShares_CV(shares);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
