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
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove liquidity directly using PoolManager (same way it was added)
contract RemoveLiquidityDirect is Script {
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
        
        console2.log("=== Removendo Liquidez Diretamente (PoolManager) ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Deployer:", deployer);
        
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
        
        // Get tick range (same as when added)
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
        
        // Try removing directly using PoolManager.unlock (like LiquidityHelper does)
        // But we need to handle the callback ourselves
        // Actually, let's try a simpler approach: use the exact same format as AddLiquidity
        // but with negative delta
        
        // Remove in very small parts to avoid overflow
        // Start with just 10% to test
        uint256 liquidityToRemove = (uint256(currentLiquidity) * 10) / 100;
        int256 liquidityDelta = -int256(liquidityToRemove);
        
        console2.log("\n=== Tentando Remover 10% ===");
        console2.log("Liquidity to remove:", liquidityToRemove);
        console2.log("Liquidity Delta:", liquidityDelta);
        
        // Approve PoolManager (needed for settlement)
        IERC20Minimal(token0).approve(poolManagerAddress, type(uint256).max);
        IERC20Minimal(token1).approve(poolManagerAddress, type(uint256).max);
        
        // Try using modifyLiquidity directly (this won't work without unlock, but let's see the error)
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        console2.log("Tentando remover diretamente...");
        console2.log("NOTA: Isso provavelmente vai falhar porque precisa de unlock callback");
        console2.log("Mas vamos ver o erro para entender melhor o problema");
        
        // This will fail, but the error message might help
        try poolManager.modifyLiquidity(poolKey, params, hookData) returns (BalanceDelta delta, BalanceDelta feesDelta) {
            console2.log("SUCCESS! Liquidity removed!");
            console2.log("Delta Amount0:", delta.amount0());
            console2.log("Delta Amount1:", delta.amount1());
        } catch Error(string memory reason) {
            console2.log("Error:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Low-level error (hex):", vm.toString(lowLevelData));
            // Try to decode as SafeCastOverflow
            if (lowLevelData.length >= 4) {
                bytes4 errorSelector = bytes4(lowLevelData);
                console2.log("Error selector:", vm.toString(errorSelector));
            }
        }
        
        vm.stopBroadcast();
    }
}

