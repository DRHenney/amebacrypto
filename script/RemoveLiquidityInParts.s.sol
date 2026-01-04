// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove liquidity in parts (to avoid SafeCastOverflow)
contract RemoveLiquidityInParts is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envOr("OLD_HOOK_ADDRESS", address(0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540));
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
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
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Removendo Liquidez em Partes ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("\n=== Estado Atual da Pool ===");
        console2.log("Current Liquidity:", currentLiquidity);
        
        if (currentLiquidity == 0) {
            console2.log("\nAVISO: A pool nao tem liquidez!");
            vm.stopBroadcast();
            return;
        }
        
        // Get token addresses
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        // Get balances before
        uint256 deployerBalance0Before = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1Before = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("\n=== Saldos Antes ===");
        console2.log("USDC Balance:", deployerBalance0Before);
        console2.log("WETH Balance:", deployerBalance1Before);
        console2.log("WETH Balance (WETH):", deployerBalance1Before / 1e18);
        
        // Get tick range
        int24 tickLower = -887220;
        int24 tickUpper = 887220;
        
        try AutoCompoundHook(hookAddress).getPoolInfo(poolKey) returns (
            AutoCompoundHook.PoolConfig memory,
            uint256,
            uint256,
            int24 lower,
            int24 upper
        ) {
            if (lower != 0 || upper != 0) {
                tickLower = lower;
                tickUpper = upper;
            }
        } catch {}
        
        console2.log("\n=== Range de Ticks ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        
        // Deploy helper
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Remove in smaller parts (like MigrateLiquidityToNewHook does)
        // Remove 50% first, then the remainder
        uint128 liquidityToRemovePart1 = uint128((uint256(currentLiquidity) * 50) / 100);
        uint128 liquidityToRemovePart2 = currentLiquidity - liquidityToRemovePart1;
        
        console2.log("\n=== Removendo em 2 Partes ===");
        console2.log("Part 1 (50%):", liquidityToRemovePart1);
        console2.log("Part 2 (restante):", liquidityToRemovePart2);
        
        // Part 1: Remove 50%
        console2.log("\n--- Parte 1: Removendo 50% ---");
        ModifyLiquidityParams memory params1 = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int128(int256(uint256(liquidityToRemovePart1))),
            salt: bytes32(0)
        });
        
        BalanceDelta delta1 = helper.removeLiquidity(poolKey, params1, "");
        console2.log("Delta Amount0:", delta1.amount0());
        console2.log("Delta Amount1:", delta1.amount1());
        
        // Check liquidity after part 1
        uint128 liquidityAfterPart1 = poolManager.getLiquidity(poolId);
        console2.log("Liquidity after part 1:", liquidityAfterPart1);
        
        // Part 2: Remove remainder (only if there's still liquidity)
        if (liquidityAfterPart1 > 0) {
            console2.log("\n--- Parte 2: Removendo restante ---");
            // Use the actual remaining liquidity to avoid any issues
            uint128 liquidityToRemovePart2Actual = liquidityAfterPart1;
            
            ModifyLiquidityParams memory params2 = ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -int128(int256(uint256(liquidityToRemovePart2Actual))),
                salt: bytes32(0)
            });
            
            BalanceDelta delta2 = helper.removeLiquidity(poolKey, params2, "");
            console2.log("Delta Amount0:", delta2.amount0());
            console2.log("Delta Amount1:", delta2.amount1());
        }
        
        // Get balances after
        uint256 deployerBalance0After = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1After = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("\n=== Saldos Depois ===");
        console2.log("USDC Balance:", deployerBalance0After);
        console2.log("WETH Balance:", deployerBalance1After);
        console2.log("WETH Balance (WETH):", deployerBalance1After / 1e18);
        
        uint256 wethReceived = deployerBalance1After > deployerBalance1Before ? 
            deployerBalance1After - deployerBalance1Before : 0;
        
        console2.log("\n=== WETH Recebido ===");
        console2.log("WETH Recebido (wei):", wethReceived);
        console2.log("WETH Recebido (WETH):", wethReceived / 1e18);
        
        // Final liquidity check
        uint128 finalLiquidity = poolManager.getLiquidity(poolId);
        console2.log("\n=== Liquidez Final ===");
        console2.log("Final Liquidity:", finalLiquidity);
        
        if (finalLiquidity == 0) {
            console2.log("[SUCCESS] Toda a liquidez foi removida!");
        }
        
        vm.stopBroadcast();
    }
}

