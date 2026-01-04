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
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script para verificar o estado atual do hook na Sepolia
contract VerifyHookState is Script {
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
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        PoolId poolId = poolKey.toId();
        
        console2.log("========================================");
        console2.log("  VERIFICACAO DO ESTADO DO HOOK");
        console2.log("========================================\n");
        
        // 1. Informacoes basicas
        console2.log("=== Informacoes Basicas ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Owner:", hook.owner());
        console2.log("");
        
        // 2. Configuracao da Pool
        console2.log("=== Configuracao da Pool ===");
        (
            AutoCompoundHook.PoolConfig memory config,
            uint256 fees0,
            uint256 fees1,
            int24 tickLower,
            int24 tickUpper
        ) = hook.getPoolInfo(poolKey);
        
        console2.log("Pool Enabled:", config.enabled);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // 3. Fees Acumuladas
        console2.log("=== Fees Acumuladas ===");
        console2.log("Fees0 (Token0):", fees0);
        console2.log("Fees1 (Token1):", fees1);
        
        // Converter para valores legiveis (assumindo 18 decimais para ambos)
        if (fees0 > 0) {
            console2.log("Fees0 (formato legivel):", fees0 / 1e12, "USDC (6 decimais)");
        }
        if (fees1 > 0) {
            console2.log("Fees1 (formato legivel):", fees1 / 1e15, "WETH (18 decimais)");
        }
        console2.log("");
        
        // 4. Saldos do Hook
        console2.log("=== Saldos do Hook ===");
        uint256 hookBalanceToken0;
        uint256 hookBalanceToken1;
        
        if (Currency.unwrap(poolKey.currency0) == address(0)) {
            hookBalanceToken0 = address(hook).balance;
            console2.log("Hook ETH Balance:", hookBalanceToken0);
        } else {
            hookBalanceToken0 = IERC20Minimal(Currency.unwrap(poolKey.currency0)).balanceOf(address(hook));
            console2.log("Hook Token0 Balance:", hookBalanceToken0);
        }
        
        if (Currency.unwrap(poolKey.currency1) == address(0)) {
            hookBalanceToken1 = address(hook).balance;
            console2.log("Hook ETH Balance:", hookBalanceToken1);
        } else {
            hookBalanceToken1 = IERC20Minimal(Currency.unwrap(poolKey.currency1)).balanceOf(address(hook));
            console2.log("Hook Token1 Balance:", hookBalanceToken1);
        }
        console2.log("");
        
        // 5. Estado da Pool
        console2.log("=== Estado da Pool ===");
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(poolId);
        console2.log("SqrtPriceX96:", sqrtPriceX96);
        console2.log("Tick:", tick);
        console2.log("Protocol Fee:", protocolFee);
        console2.log("LP Fee:", lpFee);
        
        uint128 liquidity = poolManager.getLiquidity(poolId);
        console2.log("Liquidity:", uint256(liquidity));
        console2.log("");
        
        // 6. Status do Compound
        console2.log("=== Status do Compound ===");
        (
            bool canCompound,
            string memory reason,
            uint256 timeUntilNextCompound,
            uint256 feesValueUSD,
            uint256 gasCostUSD
        ) = hook.canExecuteCompound(poolKey);
        
        console2.log("Can Execute Compound:", canCompound);
        console2.log("Reason:", reason);
        
        if (timeUntilNextCompound > 0) {
            uint256 hoursRemaining = timeUntilNextCompound / 3600;
            uint256 minutesRemaining = (timeUntilNextCompound % 3600) / 60;
            console2.log("Time Until Next Compound (seconds):", timeUntilNextCompound);
            console2.log("Time Until Next Compound (hours):", hoursRemaining);
            console2.log("Time Until Next Compound (minutes remaining):", minutesRemaining);
        } else {
            console2.log("Time Until Next Compound: 0 (pode executar agora)");
        }
        
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        if (gasCostUSD > 0 && feesValueUSD > 0) {
            uint256 ratio = (feesValueUSD * 100) / gasCostUSD;
            console2.log("Fees/Gas Ratio:", ratio, "x");
            console2.log("Required Ratio: 20x");
            console2.log("Meets Requirement:", feesValueUSD >= (gasCostUSD * 20));
        }
        console2.log("");
        
        // 7. Ultimo Compound
        uint256 lastCompound = hook.lastCompoundTimestamp(poolId);
        if (lastCompound > 0) {
            console2.log("=== Ultimo Compound ===");
            console2.log("Timestamp:", lastCompound);
            console2.log("Block Timestamp:", block.timestamp);
            uint256 timeSinceLastCompound = block.timestamp - lastCompound;
            console2.log("Time Since Last Compound:", timeSinceLastCompound, "seconds");
            console2.log("Time Since Last Compound:", timeSinceLastCompound / 3600, "hours");
        } else {
            console2.log("=== Ultimo Compound ===");
            console2.log("Nenhum compound executado ainda");
        }
        console2.log("");
        
        // 8. Precos dos Tokens
        console2.log("=== Precos Configurados ===");
        // Note: Nao ha getter publico para precos, entao nao podemos verificar diretamente
        console2.log("(Precos nao visiveis diretamente - verificados via canExecuteCompound)");
        console2.log("");
        
        // 9. Resumo
        console2.log("========================================");
        console2.log("  RESUMO");
        console2.log("========================================");
        console2.log("Pool Configurada:", config.enabled ? "SIM" : "NAO");
        console2.log("Fees Acumuladas:", (fees0 > 0 || fees1 > 0) ? "SIM" : "NAO");
        console2.log("Pode Executar Compound:", canCompound ? "SIM" : "NAO");
        if (!canCompound && bytes(reason).length > 0) {
            console2.log("Motivo:", reason);
        }
        console2.log("========================================\n");
    }
}

