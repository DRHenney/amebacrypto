// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para verificar tempo até próximo compound
contract CheckCompoundTime is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
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
        
        console2.log("=== Tempo Ate Proximo Compound ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // Verificar status do compound
        (
            bool canCompound,
            string memory reason,
            uint256 timeUntilNextCompound,
            uint256 feesValueUSD,
            uint256 gasCostUSD
        ) = hook.canExecuteCompound(poolKey);
        
        // Verificar último compound timestamp
        uint256 lastCompoundTimestamp = hook.lastCompoundTimestamp(poolId);
        uint256 currentTimestamp = block.timestamp;
        
        console2.log("=== Status Atual ===");
        console2.log("Pode Executar Compound:", canCompound);
        
        if (!canCompound && bytes(reason).length > 0) {
            console2.log("Motivo:", reason);
        }
        console2.log("");
        
        // Tempo até próximo compound
        if (timeUntilNextCompound > 0) {
            uint256 hoursRemaining = timeUntilNextCompound / 3600;
            uint256 minutesRemaining = (timeUntilNextCompound % 3600) / 60;
            uint256 secondsRemaining = timeUntilNextCompound % 60;
            
            console2.log("=== Tempo Restante ===");
            console2.log("Tempo Total (segundos):", timeUntilNextCompound);
            console2.log("Horas:", hoursRemaining);
            console2.log("Minutos:", minutesRemaining);
            console2.log("Segundos:", secondsRemaining);
            console2.log("");
            
            // Formato legível
            console2.log("Tempo Formatado:");
            if (hoursRemaining > 0) {
                console2.log("  Horas:", hoursRemaining);
                console2.log("  Minutos:", minutesRemaining);
                console2.log("  Segundos:", secondsRemaining);
            } else if (minutesRemaining > 0) {
                console2.log("  Minutos:", minutesRemaining);
                console2.log("  Segundos:", secondsRemaining);
            } else {
                console2.log("  Segundos:", secondsRemaining);
            }
        } else {
            console2.log("=== Tempo Restante ===");
            console2.log("PODE EXECUTAR AGORA! (0 segundos restantes)");
        }
        console2.log("");
        
        // Informações adicionais
        if (lastCompoundTimestamp > 0) {
            uint256 timeElapsed = currentTimestamp - lastCompoundTimestamp;
            uint256 hoursElapsed = timeElapsed / 3600;
            uint256 minutesElapsed = (timeElapsed % 3600) / 60;
            
            console2.log("=== Ultimo Compound ===");
            console2.log("Timestamp do ultimo compound:", lastCompoundTimestamp);
            console2.log("Tempo desde ultimo compound (segundos):", timeElapsed);
            console2.log("  Horas:", hoursElapsed);
            console2.log("  Minutos:", minutesElapsed);
        } else {
            console2.log("=== Ultimo Compound ===");
            console2.log("Nenhum compound executado ainda");
        }
        console2.log("");
        
        // Fees e custos
        console2.log("=== Informacoes Economicas ===");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        if (feesValueUSD > 0 && gasCostUSD > 0) {
            uint256 multiplier = feesValueUSD / gasCostUSD;
            console2.log("Multiplier (fees/gas):", multiplier, "x");
        }
    }
}

