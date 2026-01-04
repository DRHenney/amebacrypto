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
import {CompoundHelper} from "../src/helpers/CompoundHelper.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

/// @notice Script to test the auto-compound functionality
contract TestCompound is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    
    IPoolManager public poolManager;
    AutoCompoundHook public hook;
    PoolKey public poolKey;
    PoolId public poolId;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        poolManager = IPoolManager(poolManagerAddress);
        hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        poolId = poolKey.toId();
        
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Testing Auto-Compound ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("");
        
        // Check status before compound
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Status Before Compound ===");
        console2.log("Accumulated Fees0 (USDC):", fees0Before);
        console2.log("Accumulated Fees1 (WETH):", fees1Before);
        
        // Get pool liquidity before - getSlot0 returns (sqrtPriceX96, tick, protocolFee, lpFee)
        // We need to get liquidity separately
        (uint160 sqrtPriceX96Before, int24 tickBefore,,) = poolManager.getSlot0(poolId);
        // Note: liquidity is not directly available from getSlot0, we'll check fees instead
        console2.log("Pool SqrtPriceX96 Before:", sqrtPriceX96Before);
        console2.log("Pool Tick Before:", tickBefore);
        console2.log("");
        
        // Check if compound can be executed
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        console2.log("");
        
        if (!canCompound) {
            console2.log("Compound cannot be executed at this time.");
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                console2.log("Wait seconds:", timeUntilNext);
                console2.log("Wait hours:", timeUntilNext / 3600);
                console2.log("before trying again.");
            }
            vm.stopBroadcast();
            return;
        }
        
        // Check if prepareCompound exists on the deployed hook
        console2.log("=== Preparing Compound ===");
        
        ModifyLiquidityParams memory params;
        uint256 fees0ToCompound;
        uint256 fees1ToCompound;
        
        // Try to call prepareCompound using low-level call to check if function exists
        bytes4 selector = bytes4(keccak256("prepareCompound((address,address,uint24,int24,address))"));
        (bool success, bytes memory returnData) = address(hook).staticcall(
            abi.encodeWithSelector(selector, poolKey)
        );
        
        if (!success || returnData.length == 0) {
            console2.log("");
            console2.log("ERROR: prepareCompound() function not found on deployed hook!");
            console2.log("");
            console2.log("The hook at address", address(hook));
            console2.log("is using an OLD version that doesn't have the new compound functionality.");
            console2.log("");
            console2.log("Current fees accumulated:");
            console2.log("  USDC:", fees0Before);
            console2.log("  WETH:", fees1Before);
            console2.log("");
            console2.log("SOLUTION:");
            console2.log("The hook code has been updated locally but needs to be redeployed.");
            console2.log("");
            console2.log("However, note that:");
            console2.log("  - Redeploying creates a NEW hook address");
            console2.log("  - You'll need to create a NEW pool with the new hook");
            console2.log("  - Current pool cannot be migrated");
            console2.log("");
            console2.log("For now, the old hook still accumulates fees correctly,");
            console2.log("but compound requires the new version.");
            vm.stopBroadcast();
            return;
        }
        
        // Decode the result
        (bool canCompoundPrepared, ModifyLiquidityParams memory preparedParams, uint256 fees0, uint256 fees1) = 
            abi.decode(returnData, (bool, ModifyLiquidityParams, uint256, uint256));
        
        if (!canCompoundPrepared) {
            console2.log("Compound cannot be prepared at this time.");
            console2.log("");
            console2.log("All conditions must be met:");
            console2.log("1. Pool enabled");
            console2.log("2. 4 hours elapsed since last compound");
            console2.log("3. Fees accumulated > 0");
            console2.log("4. Fees value >= 20x gas cost");
            console2.log("5. Tick range configured");
            console2.log("6. Liquidity delta > 0");
            vm.stopBroadcast();
            return;
        }
        
        params = preparedParams;
        fees0ToCompound = fees0;
        fees1ToCompound = fees1;
        
        console2.log("Compound prepared successfully!");
        console2.log("Fees0 to compound:", fees0ToCompound);
        console2.log("Fees1 to compound:", fees1ToCompound);
        console2.log("Liquidity Delta:", params.liquidityDelta);
        console2.log("");
        
        // Execute compound via helper
        console2.log("=== Executing Compound via Helper ===");
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        console2.log("CompoundHelper deployed at:", address(helper));
        console2.log("");
        
        try helper.executeCompound(poolKey, params, fees0ToCompound, fees1ToCompound) returns (BalanceDelta delta) {
            console2.log("Compound executed successfully!");
            console2.log("Delta Amount0:", delta.amount0());
            console2.log("Delta Amount1:", delta.amount1());
        } catch Error(string memory errorReason) {
            console2.log("Compound failed with error:", errorReason);
            vm.stopBroadcast();
            return;
        } catch (bytes memory lowLevelData) {
            console2.log("Compound failed with low-level error");
            console2.log("Error data length:", lowLevelData.length);
            vm.stopBroadcast();
            return;
        }
        
        // Check status after compound
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Status After Compound ===");
        console2.log("Accumulated Fees0 (USDC):", fees0After);
        console2.log("Accumulated Fees1 (WETH):", fees1After);
        console2.log("Fees0 Reinvested:", fees0Before - fees0After);
        console2.log("Fees1 Reinvested:", fees1Before - fees1After);
        
        // Get pool state after
        (uint160 sqrtPriceX96After, int24 tickAfter,,) = poolManager.getSlot0(poolId);
        console2.log("Pool SqrtPriceX96 After:", sqrtPriceX96After);
        console2.log("Pool Tick After:", tickAfter);
        console2.log("");
        
        // Verify compound worked
        if (fees0After < fees0Before || fees1After < fees1Before) {
            console2.log("SUCCESS: Fees were reinvested!");
            console2.log("The compound was successful - fees were converted to liquidity!");
        } else {
            console2.log("WARNING: Fees were not reduced (compound may have failed)");
        }
        
        vm.stopBroadcast();
    }
}

