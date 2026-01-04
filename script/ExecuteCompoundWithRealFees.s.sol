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

/// @notice Script to configure CompoundHelper and execute compound using real fees
contract ExecuteCompoundWithRealFees is Script {
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
        
        console2.log("=== Configure and Execute Compound with Real Fees ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("");
        
        // Step 1: Check if CompoundHelper function exists and is configured
        CompoundHelper helper;
        bool useRealFees = false;
        
        // Try to check if compoundHelper function exists
        bytes4 compoundHelperSelector = bytes4(keccak256("compoundHelper((bytes32))"));
        (bool hasCompoundHelper, bytes memory helperData) = address(hook).staticcall(
            abi.encodeWithSelector(compoundHelperSelector, poolId)
        );
        
        if (hasCompoundHelper && helperData.length > 0) {
            address existingHelper = abi.decode(helperData, (address));
            
            if (existingHelper != address(0)) {
                console2.log("=== Using Existing CompoundHelper ===");
                console2.log("CompoundHelper Address:", existingHelper);
                helper = CompoundHelper(existingHelper);
                useRealFees = true;
            } else {
                console2.log("=== Deploying New CompoundHelper ===");
                helper = new CompoundHelper(poolManager, hook);
                console2.log("CompoundHelper deployed at:", address(helper));
                console2.log("");
                
                // Try to configure the helper in the hook
                bytes4 setHelperSelector = bytes4(keccak256("setCompoundHelper((address,address,uint24,int24,address),address)"));
                (bool setSuccess,) = address(hook).call(
                    abi.encodeWithSelector(setHelperSelector, poolKey, address(helper))
                );
                
                if (setSuccess) {
                    console2.log("=== Configuring CompoundHelper in Hook ===");
                    console2.log("CompoundHelper configured successfully!");
                    useRealFees = true;
                } else {
                    console2.log("WARNING: Could not configure CompoundHelper (may not be owner)");
                    console2.log("Will use estimated fees instead");
                }
                console2.log("");
            }
        } else {
            console2.log("WARNING: Hook does not have compoundHelper function (old version)");
            console2.log("Will use estimated fees instead of real fees");
            console2.log("");
            
            // Deploy helper anyway for executing compound (but won't use real fees)
            console2.log("=== Deploying CompoundHelper (for execution only) ===");
            helper = new CompoundHelper(poolManager, hook);
            console2.log("CompoundHelper deployed at:", address(helper));
            console2.log("");
        }
        
        // Step 2: Check status before compound
        (, uint256 fees0Estimated, uint256 fees1Estimated,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Status Before Compound ===");
        console2.log("Estimated Fees0 (USDC):", fees0Estimated);
        console2.log("Estimated Fees1 (WETH):", fees1Estimated);
        console2.log("");
        
        // Step 3: Check if compound can be executed
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        if (timeUntilNext > 0) {
            console2.log("Time Until Next:", timeUntilNext, "seconds");
        }
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        console2.log("");
        
        if (!canCompound) {
            console2.log("Compound cannot be executed at this time.");
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                console2.log("Wait seconds:", timeUntilNext);
                console2.log("Wait hours:", timeUntilNext / 3600);
            }
            vm.stopBroadcast();
            return;
        }
        
        // Step 4: Prepare compound (this will use real fees if helper is configured)
        console2.log("=== Preparing Compound ===");
        (bool canCompoundPrepared, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
            hook.prepareCompound(poolKey);
        
        if (!canCompoundPrepared) {
            console2.log("Compound cannot be prepared at this time.");
            console2.log("");
            console2.log("All conditions must be met:");
            console2.log("1. Pool enabled");
            console2.log("2. 4 hours elapsed since last compound");
            console2.log("3. Fees accumulated > 0 (real or estimated)");
            console2.log("4. Fees value >= 20x gas cost");
            console2.log("5. Tick range configured");
            console2.log("6. Liquidity delta > 0");
            vm.stopBroadcast();
            return;
        }
        
        console2.log("Compound prepared successfully!");
        console2.log("Fees0 to compound:", fees0);
        console2.log("Fees1 to compound:", fees1);
        console2.log("Liquidity Delta:", params.liquidityDelta);
        console2.log("");
        
        // Step 5: Execute compound via helper
        console2.log("=== Executing Compound via Helper ===");
        console2.log("Using CompoundHelper at:", address(helper));
        console2.log("");
        
        try helper.executeCompound(poolKey, params, fees0, fees1) returns (BalanceDelta delta) {
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
        
        // Step 6: Check status after compound
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("");
        console2.log("=== Status After Compound ===");
        console2.log("Estimated Fees0 After (USDC):", fees0After);
        console2.log("Estimated Fees1 After (WETH):", fees1After);
        console2.log("Fees0 Reinvested:", fees0Estimated > fees0After ? fees0Estimated - fees0After : 0);
        console2.log("Fees1 Reinvested:", fees1Estimated > fees1After ? fees1Estimated - fees1After : 0);
        console2.log("");
        
        // Get pool state after
        (uint160 sqrtPriceX96After, int24 tickAfter,,) = poolManager.getSlot0(poolId);
        console2.log("Pool SqrtPriceX96 After:", sqrtPriceX96After);
        console2.log("Pool Tick After:", tickAfter);
        console2.log("");
        
        // Verify compound worked
        if (fees0After < fees0Estimated || fees1After < fees1Estimated) {
            console2.log("SUCCESS: Fees were reinvested!");
            console2.log("The compound was successful - fees were converted to liquidity!");
        } else {
            console2.log("WARNING: Estimated fees were not reduced (compound may have used real fees)");
        }
        
        vm.stopBroadcast();
    }
}

