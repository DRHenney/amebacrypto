// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {CompoundHelper} from "../src/helpers/CompoundHelper.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Keeper script to automatically execute compound when conditions are met
/// @dev This script should be run periodically (e.g., every hour) to check and execute compound
contract AutoCompoundKeeper is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 30000, // 3%
            tickSpacing: 600,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Auto Compound Keeper ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Check if compound can be executed
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        
        console2.log("=== Compound Check ===");
        console2.log("Can Execute Compound:", canCompound);
        if (!canCompound) {
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                console2.log("Time Until Next (seconds):", timeUntilNext);
                console2.log("Time Until Next (hours):", timeUntilNext / 3600);
                console2.log("Time Until Next (minutes):", timeUntilNext / 60);
            }
            console2.log("Fees Value (USD):", feesValueUSD / 1e18);
            console2.log("Gas Cost (USD):", gasCostUSD / 1e18);
            console2.log("");
            console2.log("Compound nao pode ser executado no momento.");
            vm.stopBroadcast();
            return;
        }
        
        console2.log("Fees Value (USD):", feesValueUSD / 1e18);
        console2.log("Gas Cost (USD):", gasCostUSD / 1e18);
        console2.log("");
        
        // Step 2: Prepare compound
        console2.log("=== Preparing Compound ===");
        (bool canPrepare, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
            hook.prepareCompound(poolKey);
        
        if (!canPrepare) {
            console2.log("Compound nao pode ser preparado.");
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
        console2.log("");
        
        // Step 3: Get fees before compound
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Fees Before Compound ===");
        console2.log("Fees0 (USDC):", fees0Before);
        console2.log("Fees1 (WETH):", fees1Before);
        console2.log("");
        
        // Step 4: Deploy or get CompoundHelper
        // Note: In production, you might want to reuse the same CompoundHelper
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        console2.log("=== Executing Compound ===");
        console2.log("CompoundHelper:", address(helper));
        console2.log("");
        
        // Step 5: Approve CompoundHelper to spend tokens
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        console2.log("Approved CompoundHelper for both tokens");
        console2.log("");
        
        // Step 6: Execute compound
        try helper.executeCompound(poolKey, params, fees0, fees1) returns (BalanceDelta delta) {
            console2.log("=== Compound Executed Successfully! ===");
            console2.log("Delta Amount0:", delta.amount0());
            console2.log("Delta Amount1:", delta.amount1());
            console2.log("");
            
            // Step 7: Check fees after compound
            (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
            console2.log("=== Fees After Compound ===");
            console2.log("Fees0 (USDC):", fees0After);
            console2.log("Fees1 (WETH):", fees1After);
            console2.log("");
            
            console2.log("=== Fees Change ===");
            int256 fees0Change = int256(fees0After) - int256(fees0Before);
            int256 fees1Change = int256(fees1After) - int256(fees1Before);
            console2.log("Fees0 Change:", fees0Change);
            console2.log("Fees1 Change:", fees1Change);
            console2.log("");
            
            if (fees0After < fees0Before || fees1After < fees1Before) {
                console2.log("SUCCESS: Fees foram reinvestidas na pool!");
                console2.log("O compound foi executado automaticamente com sucesso!");
            } else {
                console2.log("WARNING: Fees nao foram reduzidas (pode ter usado real fees)");
            }
        } catch Error(string memory errorReason) {
            console2.log("=== Compound Failed ===");
            console2.log("Error:", errorReason);
            vm.stopBroadcast();
            return;
        } catch (bytes memory) {
            console2.log("=== Compound Failed ===");
            console2.log("Low-level error occurred");
            vm.stopBroadcast();
            return;
        }
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=== Keeper Execution Complete ===");
        console2.log("Next check should be in 4 hours (or when fees accumulate)");
    }
}

