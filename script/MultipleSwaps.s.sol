// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Script to execute multiple swaps to generate fees for compound testing
contract MultipleSwaps is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    IPoolManager public poolManager;
    AutoCompoundHook public hook;
    PoolKey public poolKey;
    PoolId public poolId;
    SwapHelper public helper;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Number of swaps to execute (default: 10)
        uint256 numSwaps = vm.envOr("NUM_SWAPS", uint256(10));
        
        // Amount per swap (default: 0.001 WETH)
        uint256 wethAmountPerSwap = vm.envOr("SWAP_WETH_AMOUNT", uint256(1000000000000000)); // 0.001 WETH
        
        // Alternate swap directions (true = alternate, false = all same direction)
        bool alternateDirections = vm.envOr("ALTERNATE_DIRECTIONS", true);
        
        poolManager = IPoolManager(poolManagerAddress);
        hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey (tokens must be in ascending order)
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
        
        IERC20Minimal weth = IERC20Minimal(Currency.unwrap(poolKey.currency1));
        IERC20Minimal usdc = IERC20Minimal(Currency.unwrap(poolKey.currency0));
        
        // Check initial balances
        uint256 wethBalanceBefore = weth.balanceOf(deployer);
        uint256 usdcBalanceBefore = usdc.balanceOf(deployer);
        
        console2.log("=== Multiple Swaps to Generate Fees ===");
        console2.log("Your address:", deployer);
        console2.log("Number of swaps:", numSwaps);
        console2.log("Amount per swap:", wethAmountPerSwap, "wei");
        console2.log("Amount per swap:", wethAmountPerSwap / 1e18, "WETH");
        console2.log("Alternate directions:", alternateDirections);
        console2.log("");
        console2.log("Initial balances:");
        console2.log("WETH balance:", wethBalanceBefore);
        console2.log("USDC balance:", usdcBalanceBefore);
        
        // Check total amount needed
        uint256 totalWethNeeded = wethAmountPerSwap * numSwaps;
        if (wethBalanceBefore < totalWethNeeded) {
            console2.log("\nWARNING: Insufficient WETH balance!");
            console2.log("You have:", wethBalanceBefore);
            console2.log("You need:", totalWethNeeded);
            console2.log("Will attempt to do as many swaps as possible...");
            numSwaps = wethBalanceBefore / wethAmountPerSwap;
            if (numSwaps == 0) {
                console2.log("ERROR: Not enough WETH for even one swap!");
                return;
            }
            console2.log("Adjusted to", numSwaps, "swaps");
        }
        
        // Check initial fees
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Initial Pool Fees ===");
        console2.log("Fees0 (USDC):", fees0Before);
        console2.log("Fees1 (WETH):", fees1Before);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy helper contract (only once)
        helper = new SwapHelper(poolManager);
        console2.log("\nSwapHelper deployed at:", address(helper));
        
        // Approve helper to spend tokens
        weth.approve(address(helper), type(uint256).max);
        usdc.approve(address(helper), type(uint256).max);
        console2.log("Approved helper for WETH and USDC");
        
        bytes memory hookData = "";
        
        uint256 totalFees0 = 0;
        uint256 totalFees1 = 0;
        
        console2.log("\n=== Executing Swaps ===");
        
        for (uint256 i = 0; i < numSwaps; i++) {
            bool zeroForOne;
            uint256 swapAmount;
            
            // Determine swap direction
            if (alternateDirections) {
                // Alternate: even swaps = WETH->USDC, odd swaps = USDC->WETH
                zeroForOne = (i % 2 == 1); // true = Token0->Token1, false = Token1->Token0
                swapAmount = wethAmountPerSwap;
            } else {
                // All swaps same direction: WETH->USDC
                zeroForOne = false;
                swapAmount = wethAmountPerSwap;
            }
            
            // Adjust amount for USDC->WETH swaps (convert WETH amount to approximate USDC amount)
            uint256 actualSwapAmount = swapAmount;
            if (zeroForOne) {
                // For USDC->WETH, approximate: 0.001 WETH ≈ $3, so use ~3000 USDC (6 decimals)
                actualSwapAmount = 3000 * 1e6; // 3000 USDC
                
                // Check if we have enough USDC
                uint256 currentUsdcBalance = usdc.balanceOf(deployer);
                if (currentUsdcBalance < actualSwapAmount) {
                    console2.log("\nSwap", i + 1, ": Skipping (insufficient USDC balance)");
                    continue;
                }
            } else {
                // Check if we have enough WETH
                uint256 currentWethBalance = weth.balanceOf(deployer);
                if (currentWethBalance < actualSwapAmount) {
                    console2.log("\nSwap", i + 1, ": Skipping (insufficient WETH balance)");
                    break;
                }
            }
            
            console2.log("\n--- Swap");
            console2.log("Swap number:", i + 1);
            console2.log("Total swaps:", numSwaps);
            if (zeroForOne) {
                console2.log("Direction: USDC -> WETH");
                console2.log("Amount (USDC):", actualSwapAmount / 1e6);
            } else {
                console2.log("Direction: WETH -> USDC");
                console2.log("Amount (WETH):", actualSwapAmount / 1e18);
            }
            
            SwapParams memory swapParams = SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(actualSwapAmount), // Negative = exactInput
                sqrtPriceLimitX96: zeroForOne ? 
                    (TickMath.MIN_SQRT_PRICE + 1) : // USDC->WETH: price decreases
                    (TickMath.MAX_SQRT_PRICE - 1)   // WETH->USDC: price increases
            });
            
            try helper.swap(poolKey, swapParams, hookData) returns (BalanceDelta delta) {
                console2.log("Success! Delta0:", delta.amount0());
                console2.log("Success! Delta1:", delta.amount1());
                
                // Check fees after this swap
                (, uint256 fees0AfterSwap, uint256 fees1AfterSwap,,) = hook.getPoolInfo(poolKey);
                uint256 fees0Accumulated = fees0AfterSwap - fees0Before - totalFees0;
                uint256 fees1Accumulated = fees1AfterSwap - fees1Before - totalFees1;
                
                totalFees0 = fees0AfterSwap - fees0Before;
                totalFees1 = fees1AfterSwap - fees1Before;
                
                console2.log("Fees accumulated this swap - USDC:", fees0Accumulated);
                console2.log("Fees accumulated this swap - WETH:", fees1Accumulated);
            } catch Error(string memory errReason) {
                console2.log("Swap failed:");
                console2.log(errReason);
                break;
            } catch {
                console2.log("Swap failed with unknown error");
                break;
            }
            
            // Small delay between swaps (optional, for blockchain to process)
            // In testnet this is usually fine without delay
        }
        
        // Final balances
        uint256 wethBalanceAfter = weth.balanceOf(deployer);
        uint256 usdcBalanceAfter = usdc.balanceOf(deployer);
        
        console2.log("\n=== Final Balances ===");
        console2.log("WETH balance:", wethBalanceAfter);
        console2.log("USDC balance:", usdcBalanceAfter);
        console2.log("WETH spent:", wethBalanceBefore - wethBalanceAfter);
        console2.log("USDC net change:", int256(usdcBalanceAfter) - int256(usdcBalanceBefore));
        
        // Final fees
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Final Pool Fees ===");
        console2.log("Fees0 (USDC):", fees0After);
        console2.log("Fees1 (WETH):", fees1After);
        console2.log("Total Fees Accumulated - USDC:", fees0After - fees0Before);
        console2.log("Total Fees Accumulated - WETH:", fees1After - fees1Before);
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("\n=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        if (timeUntilNext > 0) {
            console2.log("Time Until Next (hours):", timeUntilNext / 3600);
        }
        
        console2.log("\n=== Multiple Swaps Complete! ===");
        console2.log("Total swaps executed successfully");
        console2.log("Fees have been accumulated and are ready for compound (when time passes)");
        
        vm.stopBroadcast();
    }
}
