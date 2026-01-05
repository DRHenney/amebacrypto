// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CompoundHelper} from "../src/helpers/CompoundHelper.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to execute compound in the updated pool (fee 3%, tickSpacing 600)
contract ExecuteCompoundUpdated is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        // Create PoolKey for updated pool (fee 3%, tickSpacing 600)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 30000, // 3% - updated pool
            tickSpacing: 600, // tickSpacing for 3% fee
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Execute Compound (Updated Pool) ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("Fee: 3%");
        console2.log("Tick Spacing: 600");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Check status before compound
        (, uint256 fees0Before, uint256 fees1Before, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        console2.log("=== Status Antes do Compound ===");
        console2.log("Fees0 (USDC):", fees0Before);
        console2.log("Fees1 (WETH):", fees1Before);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // Step 2: Check if compound can be executed
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("=== Status do Compound ===");
        console2.log("Can Execute Compound:", canCompound);
        if (!canCompound) {
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                console2.log("Time Until Next (seconds):", timeUntilNext);
                console2.log("Time Until Next (hours):", timeUntilNext / 3600);
            }
        }
        console2.log("Fees Value (USD):", feesValueUSD / 1e18);
        console2.log("Gas Cost (USD):", gasCostUSD / 1e18);
        console2.log("");
        
        if (!canCompound) {
            console2.log("Compound nao pode ser executado no momento.");
            console2.log("Razao:", reason);
            vm.stopBroadcast();
            return;
        }
        
        // Step 3: Prepare compound
        console2.log("=== Preparando Compound ===");
        (bool canCompoundPrepared, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
            hook.prepareCompound(poolKey);
        
        if (!canCompoundPrepared) {
            console2.log("Compound nao pode ser preparado no momento.");
            console2.log("");
            console2.log("Todas as condicoes devem ser atendidas:");
            console2.log("1. Pool habilitada");
            console2.log("2. 4 horas desde o ultimo compound");
            console2.log("3. Fees acumuladas > 0");
            console2.log("4. Fees value >= 20x gas cost (ou precos nao configurados)");
            console2.log("5. Tick range configurado");
            console2.log("6. Liquidity delta > 0");
            vm.stopBroadcast();
            return;
        }
        
        console2.log("Compound preparado com sucesso!");
        console2.log("Fees0 para compound:", fees0);
        console2.log("Fees1 para compound:", fees1);
        console2.log("Liquidity Delta:", params.liquidityDelta);
        console2.log("Tick Lower:", params.tickLower);
        console2.log("Tick Upper:", params.tickUpper);
        console2.log("");
        
        // Step 4: Deploy or get CompoundHelper
        // For now, we'll deploy a new helper each time (it's cheap)
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        console2.log("=== Executando Compound via Helper ===");
        console2.log("CompoundHelper:", address(helper));
        console2.log("");
        
        // Step 4.5: Approve CompoundHelper to spend tokens (needed for settle via transferFrom)
        // The CurrencySettler.settle uses transferFrom(deployer, poolManager, amount)
        // The transferFrom is called by CompoundHelper, so deployer needs to approve CompoundHelper
        IERC20Minimal(token0Address).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1Address).approve(address(helper), type(uint256).max);
        console2.log("Approved CompoundHelper for both tokens");
        console2.log("");
        
        // Step 5: Execute compound via helper
        try helper.executeCompound(poolKey, params, fees0, fees1) returns (BalanceDelta delta) {
            console2.log("Compound executado com sucesso!");
            console2.log("Delta Amount0:", delta.amount0());
            console2.log("Delta Amount1:", delta.amount1());
        } catch Error(string memory errorReason) {
            console2.log("Compound falhou com erro:", errorReason);
            vm.stopBroadcast();
            return;
        } catch (bytes memory) {
            console2.log("Compound falhou com low-level error");
            vm.stopBroadcast();
            return;
        }
        
        // Step 6: Check status after compound
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("");
        console2.log("=== Status Depois do Compound ===");
        console2.log("Fees0 (USDC):", fees0After);
        console2.log("Fees1 (WETH):", fees1After);
        console2.log("");
        
        console2.log("=== Mudanca nas Fees ===");
        int256 fees0Change = int256(fees0After) - int256(fees0Before);
        int256 fees1Change = int256(fees1After) - int256(fees1Before);
        console2.log("Fees0 Change:", fees0Change);
        console2.log("Fees1 Change:", fees1Change);
        console2.log("");
        
        if (fees0After < fees0Before || fees1After < fees1Before) {
            console2.log("SUCCESS: Fees foram reinvestidas!");
            console2.log("O compound foi bem-sucedido - fees foram convertidas em liquidez!");
        } else {
            console2.log("WARNING: Fees nao foram reduzidas (compound pode ter usado real fees)");
        }
        
        vm.stopBroadcast();
    }
}

