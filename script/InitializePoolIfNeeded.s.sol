// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

/// @notice Script to initialize pool if not already initialized
contract InitializePoolIfNeeded is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Checking Pool Initialization ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        
        // Check if pool is initialized
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        if (sqrtPriceX96 != 0) {
            int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
            console2.log("Pool already initialized!");
            console2.log("Current sqrtPriceX96:", sqrtPriceX96);
            console2.log("Current Tick:", currentTick);
        } else {
            console2.log("Pool not initialized. Initializing...");
            // Use a starting price (1:1 ratio)
            uint160 startingPrice = uint160(79228162514264337593543950336); // sqrt(1) * 2^96
            int24 tick = poolManager.initialize(poolKey, startingPrice);
            console2.log("Pool initialized successfully!");
            console2.log("Initial Tick:", tick);
            console2.log("Starting sqrtPriceX96:", startingPrice);
        }
        
        vm.stopBroadcast();
    }
}

