// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script para verificar status completo da pool e fees acumuladas
contract CheckPoolStatus is Script {
    using CurrencyLibrary for Currency;
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
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        PoolId poolId = poolKey.toId();
        
        console2.log("==========================================");
        console2.log("    STATUS DA POOL - FEEDBACK COMPLETO");
        console2.log("==========================================");
        console2.log("");
        
        // ========== INFORMAÇÕES DA POOL ==========
        (uint160 sqrtPriceX96, int24 tick,,) = poolManager.getSlot0(poolId);
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        console2.log("=== INFORMACOES DA POOL ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Current Tick:", tick);
        console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        console2.log("Liquidity:", liquidity);
        console2.log("");
        
        // ========== FEES ACUMULADAS ==========
        (uint256 fees0, uint256 fees1) = hook.getAccumulatedFees(poolKey);
        
        console2.log("=== FEES ACUMULADAS ===");
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        console2.log("Token0 (Fees raw):", fees0);
        console2.log("Token1 (Fees raw):", fees1);
        
        // Formatar valores (USDC = 6 decimais, WETH = 18 decimais)
        // Token0 é USDC (6 decimais)
        uint256 usdcWhole = fees0 / 1e6;
        uint256 usdcDecimal = (fees0 % 1e6) / 1e3;
        console2.log("Token0 (USDC whole part):", usdcWhole);
        console2.log("Token0 (USDC decimal part):", usdcDecimal);
        
        // Token1 é WETH (18 decimais)
        uint256 wethWhole = fees1 / 1e18;
        uint256 wethDecimal = (fees1 % 1e18) / 1e15;
        console2.log("Token1 (WETH whole part):", wethWhole);
        console2.log("Token1 (WETH decimal part):", wethDecimal);
        console2.log("");
        
        // ========== STATUS DO COMPOUND ==========
        (
            bool canCompound,
            string memory reason,
            uint256 timeUntilNextCompound,
            uint256 feesValueUSD,
            uint256 gasCostUSD
        ) = hook.canExecuteCompound(poolKey);
        
        console2.log("=== STATUS DO COMPOUND ===");
        console2.log("Pode Executar Compound:", canCompound ? "SIM" : "NAO");
        
        if (!canCompound && bytes(reason).length > 0) {
            console2.log("Motivo:", reason);
        }
        console2.log("");
        
        // Tempo até próximo compound
        if (timeUntilNextCompound > 0) {
            uint256 hoursRemaining = timeUntilNextCompound / 3600;
            uint256 minutesRemaining = (timeUntilNextCompound % 3600) / 60;
            uint256 secondsRemaining = timeUntilNextCompound % 60;
            
            console2.log("=== TEMPO RESTANTE ===");
            console2.log("Horas:", hoursRemaining);
            console2.log("Minutos:", minutesRemaining);
            console2.log("Segundos:", secondsRemaining);
            console2.log("");
        } else if (canCompound) {
            console2.log("=== TEMPO RESTANTE ===");
            console2.log("PODE EXECUTAR AGORA!");
            console2.log("");
        }
        
        // Último compound
        uint256 lastCompoundTimestamp = hook.lastCompoundTimestamp(poolId);
        if (lastCompoundTimestamp > 0) {
            uint256 timeElapsed = block.timestamp - lastCompoundTimestamp;
            uint256 hoursElapsed = timeElapsed / 3600;
            uint256 minutesElapsed = (timeElapsed % 3600) / 60;
            
            console2.log("=== ULTIMO COMPOUND ===");
            console2.log("Timestamp:", lastCompoundTimestamp);
            console2.log("Tempo desde ultimo compound:");
            console2.log("  Horas:", hoursElapsed);
            console2.log("  Minutos:", minutesElapsed);
            console2.log("");
        } else {
            console2.log("=== ULTIMO COMPOUND ===");
            console2.log("Nenhum compound executado ainda");
            console2.log("");
        }
        
        // ========== INFORMAÇÕES ECONÔMICAS ==========
        console2.log("=== INFORMACOES ECONOMICAS ===");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        if (feesValueUSD > 0 && gasCostUSD > 0) {
            uint256 multiplier = feesValueUSD / gasCostUSD;
            console2.log("Multiplier (fees/gas):", multiplier, "x");
            
            if (multiplier >= 20) {
                console2.log("Status: Fees suficientes para compound!");
            } else {
                console2.log("Status: Fees insuficientes (precisa 20x gas cost)");
                uint256 neededMultiplier = 20;
                uint256 neededFeesUSD = gasCostUSD * neededMultiplier;
                console2.log("Fees necessarias (USD):", neededFeesUSD);
            }
        }
        console2.log("");
        
        // ========== CONFIGURAÇÃO DA POOL ==========
        (
            AutoCompoundHook.PoolConfig memory config,
            uint256 configFees0,
            uint256 configFees1,
            int24 tickLower,
            int24 tickUpper
        ) = hook.getPoolInfo(poolKey);
        
        console2.log("=== CONFIGURACAO DO HOOK ===");
        console2.log("Enabled:", config.enabled);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Current Tick:", tick);
        
        if (tick >= tickLower && tick <= tickUpper) {
            console2.log("Status: Preco dentro do range!");
        } else {
            console2.log("Status: Preco FORA do range");
        }
        console2.log("");
        
        // ========== RESUMO ==========
        console2.log("==========================================");
        console2.log("              RESUMO");
        console2.log("==========================================");
        console2.log("Fees Acumuladas Token0:", fees0);
        console2.log("Fees Acumuladas Token1:", fees1);
        console2.log("Compound Pode Executar:", canCompound ? "SIM" : "NAO");
        
        if (fees0 > 0 || fees1 > 0) {
            console2.log("Status Geral: Fees sendo acumuladas!");
        } else {
            console2.log("Status Geral: Sem fees acumuladas ainda");
        }
        console2.log("==========================================");
    }
}

