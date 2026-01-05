// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Script to check complete pool state
contract CheckPoolState is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 30000, // 3%
            tickSpacing: 600,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Pool State (Complete) ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("Fee: 3%");
        console2.log("Tick Spacing: 600");
        console2.log("");
        
        // Get pool state from PoolManager
        (uint160 sqrtPriceX96, int24 currentTick, uint24 protocolFee, uint24 hookFee) = 
            StateLibrary.getSlot0(poolManager, poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("=== Pool State (PoolManager) ===");
        console2.log("SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        console2.log("Current Liquidity:", currentLiquidity);
        console2.log("Protocol Fee:", protocolFee);
        console2.log("Hook Fee:", hookFee);
        console2.log("");
        
        // Calculate approximate price from tick
        // price ≈ 1.0001^tick
        // For display purposes, we'll just show the tick
        console2.log("Price approximation: 1.0001^", currentTick);
        console2.log("(Higher tick = higher price of token1 relative to token0)");
        console2.log("");
        
        // Get pool info from hook
        (AutoCompoundHook.PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = 
            hook.getPoolInfo(poolKey);
        
        console2.log("=== Pool Configuration (Hook) ===");
        console2.log("Pool Enabled:", config.enabled);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        console2.log("=== Accumulated Fees ===");
        console2.log("Fees0 (USDC):", fees0);
        console2.log("Fees1 (WETH):", fees1);
        
        // Format fees
        uint256 fees0Whole = fees0 / 1e6;
        uint256 fees0Decimal = fees0 % 1e6;
        console2.log("Fees0 (USDC) formatted:", fees0Whole, ".", fees0Decimal);
        
        uint256 fees1Whole = fees1 / 1e18;
        uint256 fees1Decimal = (fees1 % 1e18) / 1e12;
        console2.log("Fees1 (WETH) formatted:", fees1Whole, ".", fees1Decimal);
        console2.log("");
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        
        console2.log("=== Compound Status ===");
        console2.log("Can Execute Compound:", canCompound);
        if (!canCompound) {
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                console2.log("Time Until Next (seconds):", timeUntilNext);
                console2.log("Time Until Next (hours):", timeUntilNext / 3600);
            }
        }
        console2.log("Fees Value (USD):", feesValueUSD / 1e18);
        console2.log("Gas Cost (USD):", gasCostUSD / 1e18);
        console2.log("");
        
        // Summary
        console2.log("=== Summary ===");
        console2.log("Total Pool Liquidity:", currentLiquidity);
        console2.log("Current Price Tick:", currentTick);
        console2.log("Accumulated Fees (USDC):", fees0);
        console2.log("Accumulated Fees (WETH):", fees1);
        console2.log("Can Compound:", canCompound);
    }
}

