// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @notice Script para corrigir o tick range alinhando com tickSpacing
contract FixTickRange is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        console2.log("=== Fixing Tick Range ===");
        console2.log("TickSpacing: 60");
        
        // Alinhar ticks com tickSpacing
        // Para tickSpacing = 60:
        // MIN_TICK = -887272 -> floor(-887272 / 60) * 60 = -887280
        // MAX_TICK = 887272 -> floor(887272 / 60) * 60 = 887280
        int24 tickSpacing = 60;
        int24 MIN_TICK = -887272;
        int24 MAX_TICK = 887272;
        
        // Calcular ticks alinhados
        int24 tickLower = (MIN_TICK / tickSpacing) * tickSpacing;
        int24 tickUpper = (MAX_TICK / tickSpacing) * tickSpacing;
        
        console2.log("TickLower (alinhado):", tickLower);
        console2.log("TickUpper (alinhado):", tickUpper);
        console2.log("");
        
        // Verificar alinhamento
        require(tickLower % tickSpacing == 0, "TickLower not aligned");
        require(tickUpper % tickSpacing == 0, "TickUpper not aligned");
        console2.log("Ticks are aligned!");
        console2.log("");
        
        // Configurar tick range
        hook.setPoolTickRange(key, tickLower, tickUpper);
        console2.log("Tick range updated successfully!");
        
        // Verificar
        (,,, int24 storedTickLower, int24 storedTickUpper) = hook.getPoolInfo(key);
        console2.log("");
        console2.log("=== Verification ===");
        console2.log("Stored TickLower:", storedTickLower);
        console2.log("Stored TickUpper:", storedTickUpper);
        
        vm.stopBroadcast();
    }
}

