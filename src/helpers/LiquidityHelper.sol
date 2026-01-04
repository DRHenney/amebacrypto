// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";

/// @notice Helper contract to add liquidity to Uniswap v4 pools
contract LiquidityHelper is IUnlockCallback {
    using CurrencySettler for Currency;
    
    IPoolManager public immutable poolManager;
    
    struct CallbackData {
        address sender;
        PoolKey key;
        ModifyLiquidityParams params;
        bytes hookData;
    }
    
    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }
    
    /// @notice Add liquidity to a pool
    function addLiquidity(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        bytes memory hookData
    ) external returns (BalanceDelta delta) {
        bytes memory callbackData = abi.encode(CallbackData({
            sender: msg.sender,
            key: key,
            params: params,
            hookData: hookData
        }));
        
        delta = abi.decode(poolManager.unlock(callbackData), (BalanceDelta));
    }
    
    function unlockCallback(bytes calldata rawData) external override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Only PoolManager can call");
        
        CallbackData memory data = abi.decode(rawData, (CallbackData));
        
        // Modify liquidity
        (BalanceDelta delta,) = poolManager.modifyLiquidity(data.key, data.params, data.hookData);
        
        // Settle balances (negative deltas mean we owe tokens to the pool)
        int256 delta0 = delta.amount0();
        int256 delta1 = delta.amount1();
        
        if (delta0 < 0) {
            data.key.currency0.settle(poolManager, data.sender, uint256(-delta0), false);
        }
        if (delta1 < 0) {
            data.key.currency1.settle(poolManager, data.sender, uint256(-delta1), false);
        }
        
        // Take balances (positive deltas mean we receive tokens from the pool)
        if (delta0 > 0) {
            data.key.currency0.take(poolManager, data.sender, uint256(delta0), false);
        }
        if (delta1 > 0) {
            data.key.currency1.take(poolManager, data.sender, uint256(delta1), false);
        }
        
        return abi.encode(delta);
    }
    
    /// @notice Remove liquidity from a pool
    function removeLiquidity(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        bytes memory hookData
    ) external returns (BalanceDelta delta) {
        bytes memory callbackData = abi.encode(CallbackData({
            sender: msg.sender,
            key: key,
            params: params,
            hookData: hookData
        }));
        
        delta = abi.decode(poolManager.unlock(callbackData), (BalanceDelta));
    }
}

