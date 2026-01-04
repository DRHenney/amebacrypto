// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script to check liquidity in all known pools (old and new hooks)
contract CheckLiquidityInAllPools is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
        // List of known hook addresses from documentation
        address[] memory hookAddresses = new address[](4);
        hookAddresses[0] = 0x5D2221e062d9577Ceec30661A6803a5A67D6D540; // Current in .env
        hookAddresses[1] = 0xEaF32b3657427a3796928035d6B2DBb28C355540; // From DEPLOY-HOOK-ATUALIZADO-COMPLETO.md
        hookAddresses[2] = 0x01308892b21f3E6fB6fF8e13a29D775e991D5540; // From INFORMACOES-HOOK-DEPLOY.md
        hookAddresses[3] = 0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540; // From SITUACAO-COMPOUND.md (old)
        
        console2.log("=== Verificando Liquidez em Todas as Pools Conhecidas ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Token0 (USDC):", token0Address);
        console2.log("Token1 (WETH):", token1Address);
        console2.log("");
        
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        for (uint256 i = 0; i < hookAddresses.length; i++) {
            address hookAddress = hookAddresses[i];
            
            PoolKey memory poolKey = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(hookAddress)
            });
            
            PoolId poolId = poolKey.toId();
            
            console2.log("--- Hook:", hookAddress);
            console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
            
            // Check if pool exists and has liquidity
            (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
            uint128 liquidity = poolManager.getLiquidity(poolId);
            
            if (sqrtPriceX96 == 0) {
                console2.log("Status: Pool NAO inicializada");
            } else {
                console2.log("Status: Pool inicializada");
                console2.log("SqrtPriceX96:", sqrtPriceX96);
                console2.log("Current Tick:", currentTick);
                console2.log("Liquidity:", liquidity);
                
                if (liquidity > 0) {
                    console2.log(">>> LIQUIDEZ ENCONTRADA! <<<");
                }
            }
            console2.log("");
        }
        
        console2.log("=== Verificacao Completa ===");
    }
}

