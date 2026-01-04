// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script to create/initialize a pool in Uniswap v4
contract CreatePool is Script, IUnlockCallback {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    IPoolManager public poolManager;
    PoolKey public poolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Calculate starting price (1:1 ratio, sqrtPriceX96)
        // For 1:1 price: sqrt(1) * 2^96 = 2^96
        uint160 startingPrice = uint160(79228162514264337593543950336); // sqrt(1) * 2^96
        
        poolManager = IPoolManager(poolManagerAddress);
        
        // Create PoolKey (tokens must be in ascending order)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        console2.log("=== Creating Pool ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Hook:", hookAddress);
        console2.log("Token0:", Currency.unwrap(poolKey.currency0));
        console2.log("Token1:", Currency.unwrap(poolKey.currency1));
        console2.log("Fee:", poolKey.fee);
        console2.log("Starting Price (sqrtPriceX96):", startingPrice);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if pool already exists
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        if (sqrtPriceX96 != 0) {
            // Pool already initialized
            int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
            console2.log("\nPool already initialized!");
            console2.log("Current sqrtPriceX96:", sqrtPriceX96);
            console2.log("Current Tick:", currentTick);
            console2.log("Skipping initialization...");
        } else {
            // Initialize pool (doesn't require unlock)
            int24 tick = poolManager.initialize(poolKey, startingPrice);
            
            console2.log("\nPool initialized successfully!");
            console2.log("Initial Tick:", tick);
        }
        
        vm.stopBroadcast();
    }
    
    // Required by IUnlockCallback but not used here
    function unlockCallback(bytes calldata) external pure returns (bytes memory) {
        return "";
    }
}
