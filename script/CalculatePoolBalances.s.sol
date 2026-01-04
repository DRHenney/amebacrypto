// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

/// @notice Script para calcular os saldos aproximados de tokens na pool
contract CalculatePoolBalances is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
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
        
        // Get pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        uint128 totalLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("==========================================");
        console2.log("    CALCULO DE SALDOS DA POOL");
        console2.log("==========================================");
        console2.log("");
        console2.log("=== INFORMACOES DA POOL ===");
        console2.log("Current Tick:", currentTick);
        console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        console2.log("Total Liquidity:", totalLiquidity);
        console2.log("");
        
        // Get token addresses
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        console2.log("Token0 (USDC):", token0);
        console2.log("Token1 (WETH):", token1);
        console2.log("");
        
        // Calculate based on the last added range (from previous execution)
        // Tick Lower: 404940, Tick Upper: 423900
        int24 tickLower = 404940;
        int24 tickUpper = 423900;
        
        console2.log("=== CALCULO BASEADO NO RANGE DA ULTIMA ADICAO ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Current Tick:", currentTick);
        
        if (currentTick >= tickLower && currentTick <= tickUpper) {
            console2.log("Status: Preco dentro do range!");
            
            uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
            uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
            
            // Calculate token amounts for the total liquidity
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtPriceAX96,
                sqrtPriceBX96,
                totalLiquidity
            );
            
            console2.log("");
            console2.log("=== SALDOS CALCULADOS ===");
            console2.log("Token0 (USDC) - Raw:", amount0);
            console2.log("Token1 (WETH) - Raw:", amount1);
            console2.log("");
            
            // Format USDC (6 decimals)
            uint256 usdcWhole = amount0 / 1e6;
            uint256 usdcDecimal = (amount0 % 1e6);
            console2.log("Token0 (USDC):", usdcWhole, ".", usdcDecimal);
            console2.log("Token0 (USDC) formatado:", 
                string.concat(
                    vm.toString(usdcWhole),
                    ".",
                    vm.toString(usdcDecimal)
                )
            );
            
            // Format WETH (18 decimals)
            uint256 wethWhole = amount1 / 1e18;
            uint256 wethDecimal = (amount1 % 1e18) / 1e12; // Show 6 decimal places
            console2.log("Token1 (WETH):", wethWhole, ".", wethDecimal);
            console2.log("Token1 (WETH) formatado:", 
                string.concat(
                    vm.toString(wethWhole),
                    ".",
                    vm.toString(wethDecimal)
                )
            );
            
            // Calculate USD value (assuming 1 WETH = 3000 USDC for estimation)
            uint256 wethValueUSD = (wethWhole * 3000) + ((wethDecimal * 3000) / 1e6);
            uint256 totalValueUSD = usdcWhole + wethValueUSD;
            console2.log("");
            console2.log("=== VALOR ESTIMADO (assumindo 1 WETH = 3000 USDC) ===");
            console2.log("Valor USDC:", usdcWhole);
            console2.log("Valor WETH (USD):", wethValueUSD);
            console2.log("Valor Total (USD):", totalValueUSD);
        } else {
            console2.log("Status: Preco FORA do range!");
            console2.log("A liquidez pode estar em outro range ou distribuida.");
        }
        
        // Also check actual token balances in the PoolManager
        console2.log("");
        console2.log("=== SALDOS REAIS NO POOL MANAGER ===");
        uint256 poolManagerToken0Balance = IERC20Minimal(token0).balanceOf(address(poolManager));
        uint256 poolManagerToken1Balance = IERC20Minimal(token1).balanceOf(address(poolManager));
        
        console2.log("PoolManager Token0 (USDC) Balance:", poolManagerToken0Balance);
        console2.log("PoolManager Token1 (WETH) Balance:", poolManagerToken1Balance);
        
        // Format USDC
        uint256 usdcWholeReal = poolManagerToken0Balance / 1e6;
        uint256 usdcDecimalReal = poolManagerToken0Balance % 1e6;
        console2.log("PoolManager USDC:", usdcWholeReal, ".", usdcDecimalReal);
        
        // Format WETH
        uint256 wethWholeReal = poolManagerToken1Balance / 1e18;
        uint256 wethDecimalReal = (poolManagerToken1Balance % 1e18) / 1e12;
        console2.log("PoolManager WETH:", wethWholeReal, ".", wethDecimalReal);
        
        console2.log("");
        console2.log("==========================================");
        console2.log("NOTA: O calculo baseado em liquidez");
        console2.log("assume que toda a liquidez esta no");
        console2.log("range especificado. Os saldos reais");
        console2.log("no PoolManager mostram os tokens");
        console2.log("efetivamente depositados.");
        console2.log("==========================================");
    }
}

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
}

