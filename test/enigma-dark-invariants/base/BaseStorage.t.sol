// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

// Contracts
import {AaveV3ATokenWrapper} from "src/AaveV3ATokenWrapper.sol";
import {PullRewardsTransferStrategy} from "aave-v3/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";

// Mock Contracts
import {MockCollateralVaultFactory} from "test/AaveV3ATokenWrapper.t.sol";
import {TestnetERC20} from "aave-v3/mocks/testnet-helpers/TestnetERC20.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
    uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The address that is targeted when executing an action (OPTIONAL)
    address internal targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // ADMIN ADDRESSES
    address internal admin;
    address internal emissionAdmin;

    // PROTOCOL CONTRACTS
    IPool internal aavePool;
    AaveV3ATokenWrapper internal aaveV3ATokenWrapper;
    PullRewardsTransferStrategy strategy;
    address internal priceAggregatorUSDC;
    address internal priceAggregatorWETH;

    // ASSETS
    TestnetERC20 internal weth;
    TestnetERC20 internal usdc;
    IAToken internal aToken;
    address internal rewardToken;

    // MOCKS
    MockCollateralVaultFactory internal collateralVaultFactory;
    address internal collateralVault = address(3333333);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Array of base assets for the suite
    address[] internal baseAssets;

    /// @notice Array of price aggregators for the suite
    address[] internal priceAggregators;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
