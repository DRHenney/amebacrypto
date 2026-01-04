// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";

/// @notice Script to migrate liquidity from old hook to new hook
contract MigrateLiquidityToNewHook is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    IPoolManager public poolManager;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address oldHookAddress = vm.envOr("OLD_HOOK_ADDRESS", address(0xAc739f2F5c72C80a4491cf273308C3D94F00D540)); // Hook antigo da Sepolia
        address newHookAddress = vm.envAddress("HOOK_ADDRESS"); // Novo hook
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        poolManager = IPoolManager(poolManagerAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Migrating Liquidity from Old Hook to New Hook ===");
        console2.log("Old Hook:", oldHookAddress);
        console2.log("New Hook:", newHookAddress);
        console2.log("");
        
        // Create PoolKeys
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory oldPoolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(oldHookAddress)
        });
        
        PoolKey memory newPoolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(newHookAddress)
        });
        
        PoolId oldPoolId = oldPoolKey.toId();
        PoolId newPoolId = newPoolKey.toId();
        
        // Step 1: Get liquidity from old pool
        console2.log("=== Step 1: Getting liquidity from old pool ===");
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(oldPoolId);
        
        if (sqrtPriceX96 == 0) {
            console2.log("ERROR: Old pool not found or not initialized!");
            vm.stopBroadcast();
            return;
        }
        
        uint128 currentLiquidity = poolManager.getLiquidity(oldPoolId);
        console2.log("Current Liquidity:", currentLiquidity);
        console2.log("Current SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        
        if (currentLiquidity == 0) {
            console2.log("WARNING: No liquidity in old pool!");
            vm.stopBroadcast();
            return;
        }
        
        // Get tick range from old hook config
        AutoCompoundHook oldHook = AutoCompoundHook(oldHookAddress);
        (,,, int24 tickLower, int24 tickUpper) = oldHook.getPoolInfo(oldPoolKey);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // Get token balances before
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        uint256 deployerBalance0Before = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1Before = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Balances Before Removal ===");
        console2.log("Deployer Token0 Balance:", deployerBalance0Before);
        console2.log("Deployer Token1 Balance:", deployerBalance1Before);
        console2.log("");
        
        // Step 2: Remove ALL liquidity from old pool
        console2.log("=== Step 2: Removing ALL liquidity from old pool ===");
        
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Approve helper
        IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        
        // Remove liquidity in two parts to avoid overflow
        // Remove 90% first, then the remainder
        uint128 liquidityToRemovePart1 = uint128((uint256(currentLiquidity) * 90) / 100);
        uint128 liquidityToRemovePart2 = currentLiquidity - liquidityToRemovePart1;
        
        console2.log("Removing liquidity in 2 parts:");
        console2.log("Part 1:", liquidityToRemovePart1);
        console2.log("Part 2:", liquidityToRemovePart2);
        console2.log("");
        
        // Part 1: Remove 90%
        ModifyLiquidityParams memory removeParams1 = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int128(int256(uint256(liquidityToRemovePart1))),
            salt: bytes32(0)
        });
        
        BalanceDelta removeDelta1 = helper.removeLiquidity(oldPoolKey, removeParams1, "");
        console2.log("Part 1 - Remove Delta Amount0:", removeDelta1.amount0());
        console2.log("Part 1 - Remove Delta Amount1:", removeDelta1.amount1());
        
        // Part 2: Remove remainder
        ModifyLiquidityParams memory removeParams2 = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int128(int256(uint256(liquidityToRemovePart2))),
            salt: bytes32(0)
        });
        
        BalanceDelta removeDelta2 = helper.removeLiquidity(oldPoolKey, removeParams2, "");
        console2.log("Part 2 - Remove Delta Amount0:", removeDelta2.amount0());
        console2.log("Part 2 - Remove Delta Amount1:", removeDelta2.amount1());
        
        // Combine deltas for logging
        BalanceDelta removeDelta = BalanceDelta.wrap(
            BalanceDelta.unwrap(removeDelta1) + BalanceDelta.unwrap(removeDelta2)
        );
        console2.log("Remove Delta Amount0:", removeDelta.amount0());
        console2.log("Remove Delta Amount1:", removeDelta.amount1());
        console2.log("");
        
        // Get balances after removal
        uint256 deployerBalance0After = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1After = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Balances After Removal ===");
        console2.log("Deployer Token0 Balance:", deployerBalance0After);
        console2.log("Deployer Token1 Balance:", deployerBalance1After);
        console2.log("Token0 Received:", deployerBalance0After - deployerBalance0Before);
        console2.log("Token1 Received:", deployerBalance1After - deployerBalance1Before);
        console2.log("");
        
        uint256 amount0ToAdd = deployerBalance0After - deployerBalance0Before;
        uint256 amount1ToAdd = deployerBalance1After - deployerBalance1Before;
        
        // Step 3: Create/Initialize new pool
        console2.log("=== Step 3: Creating new pool with new hook ===");
        (uint160 newSqrtPriceX96,,,) = poolManager.getSlot0(newPoolId);
        
        if (newSqrtPriceX96 == 0) {
            // Initialize new pool with current price from old pool
            int24 initialTick = poolManager.initialize(newPoolKey, sqrtPriceX96);
            console2.log("New pool initialized!");
            console2.log("Initial Tick:", initialTick);
        } else {
            console2.log("New pool already initialized!");
        }
        console2.log("");
        
        // Step 4: Add liquidity to new pool
        console2.log("=== Step 4: Adding liquidity to new pool ===");
        console2.log("Amount0 to add:", amount0ToAdd);
        console2.log("Amount1 to add:", amount1ToAdd);
        
        // Get current price of new pool
        (uint160 newPoolSqrtPriceX96,,,) = poolManager.getSlot0(newPoolId);
        int24 newPoolCurrentTick = TickMath.getTickAtSqrtPrice(newPoolSqrtPriceX96);
        
        // Use same tick range or calculate new one
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        
        // Calculate liquidity from amounts
        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            newPoolSqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            amount0ToAdd,
            amount1ToAdd
        );
        
        console2.log("Liquidity to add:", liquidityToAdd);
        
        // Approve pool manager
        IERC20Minimal(token0).approve(address(poolManager), type(uint256).max);
        IERC20Minimal(token1).approve(address(poolManager), type(uint256).max);
        
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int128(liquidityToAdd),
            salt: bytes32(0)
        });
        
        (BalanceDelta addDelta,) = poolManager.modifyLiquidity(newPoolKey, addParams, "");
        console2.log("Add Delta Amount0:", addDelta.amount0());
        console2.log("Add Delta Amount1:", addDelta.amount1());
        console2.log("");
        
        // Step 5: Configure new hook
        console2.log("=== Step 5: Configuring new hook ===");
        AutoCompoundHook newHook = AutoCompoundHook(newHookAddress);
        
        // Set pool config
        newHook.setPoolConfig(newPoolKey, true);
        console2.log("Pool config set to enabled");
        
        // Set tick range
        newHook.setPoolTickRange(newPoolKey, tickLower, tickUpper);
        console2.log("Tick range configured");
        
        // Set token prices (use same as before if available, or default values)
        // For now, skip - can be set later
        console2.log("New pool configured!");
        console2.log("");
        
        console2.log("=== Migration Complete ===");
        console2.log("Old Pool ID:", vm.toString(uint256(PoolId.unwrap(oldPoolId))));
        console2.log("New Pool ID:", vm.toString(uint256(PoolId.unwrap(newPoolId))));
        console2.log("New Hook Address:", newHookAddress);
        
        vm.stopBroadcast();
    }
}

