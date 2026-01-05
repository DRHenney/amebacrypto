// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
// toBalanceDelta is a global function, no need to import
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../hooks/AutoCompoundHook.sol";

/// @title CompoundHelper
/// @notice A helper contract to handle the unlockCallback for compound operations
contract CompoundHelper is IUnlockCallback {
    using CurrencySettler for Currency;

    IPoolManager public immutable poolManager;
    AutoCompoundHook public immutable hook;
    address public immutable deployer;

    struct CallbackData {
        PoolKey key;
        ModifyLiquidityParams params;
        uint256 fees0;
        uint256 fees1;
    }

    constructor(IPoolManager _poolManager, AutoCompoundHook _hook) {
        poolManager = _poolManager;
        hook = _hook;
        deployer = msg.sender;
    }

    /// @notice Execute compound by calling the hook's compound function via unlock
    function executeCompound(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        uint256 fees0,
        uint256 fees1
    ) external returns (BalanceDelta) {
        require(msg.sender == deployer, "Only deployer can call");

        bytes memory callbackData = abi.encode(CallbackData({
            key: key,
            params: params,
            fees0: fees0,
            fees1: fees1
        }));

        return abi.decode(poolManager.unlock(callbackData), (BalanceDelta));
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "Only PoolManager can call");

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        // Modify liquidity to add liquidity (this will also credit the accumulated fees)
        // callerDelta = principalDelta + feesAccrued
        // When using real fees, feesAccrued are already applied, so callerDelta represents
        // the net amount we need to pay (negative) or receive (positive)
        (BalanceDelta callerDelta, BalanceDelta feesAccrued) = poolManager.modifyLiquidity(data.key, data.params, "");

        // Settle the callerDelta (negative means we owe tokens)
        // The feesAccrued are already included in callerDelta, so we only need to handle callerDelta
        int256 delta0 = callerDelta.amount0();
        int256 delta1 = callerDelta.amount1();

        if (delta0 < 0) {
            // We owe tokens, so we need to settle using deployer's tokens
            uint256 amount0Needed;
            unchecked {
                amount0Needed = uint256(-delta0);
            }
            data.key.currency0.settle(poolManager, deployer, amount0Needed, false);
        } else if (delta0 > 0) {
            // Positive means we receive tokens (excess after fees cover the principal)
            data.key.currency0.take(poolManager, deployer, uint256(delta0), false);
        }
        
        if (delta1 < 0) {
            uint256 amount1Needed;
            unchecked {
                amount1Needed = uint256(-delta1);
            }
            data.key.currency1.settle(poolManager, deployer, amount1Needed, false);
        } else if (delta1 > 0) {
            data.key.currency1.take(poolManager, deployer, uint256(delta1), false);
        }
        
        // Mark compound as executed in the hook using the real fees from modifyLiquidity
        uint256 realFees0 = feesAccrued.amount0() > 0 ? uint256(uint128(feesAccrued.amount0())) : 0;
        uint256 realFees1 = feesAccrued.amount1() > 0 ? uint256(uint128(feesAccrued.amount1())) : 0;
        hook.executeCompound(data.key, realFees0, realFees1);

        // Return callerDelta (which includes both principal and fees)
        return abi.encode(callerDelta);
    }
}

