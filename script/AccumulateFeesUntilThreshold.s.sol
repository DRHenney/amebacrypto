// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";

/// @notice Script para acumular fees fazendo swaps até atingir um threshold
/// @dev Executa swaps alternados até acumular fees suficientes
contract AccumulateFeesUntilThreshold is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    // Threshold em WETH (0.0001 WETH = ~$0.30)
    uint256 constant TARGET_FEES_WETH = 100000000000000; // 0.0001 WETH em wei (1e14)
    uint256 constant SWAP_SIZE_WETH = 1000000000000000;   // 0.001 WETH por swap (1e15)
    uint256 constant MAX_SWAPS = 400;              // Limite de segurança
    
    // Fee rate = 0.3% = 3000 bps
    // Cada swap de 0.001 WETH gera ~0.000003 WETH em fees
    // Para 0.001 WETH total: ~333 swaps
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        IERC20 weth = IERC20(token1Address); // Assumindo WETH é token1
        IERC20 usdc = IERC20(token0Address); // Assumindo USDC é token0
        
        address deployer = vm.addr(deployerPrivateKey);
        
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
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Accumulating Fees Until Threshold ===");
        console2.log("Target Fees: 0.0001 WETH");
        console2.log("Swap Size: 0.001 WETH per swap");
        console2.log("Max Swaps:", MAX_SWAPS);
        console2.log("");
        
        // Check initial fees
        (, uint256 fees0Initial, uint256 fees1Initial,,) = hook.getPoolInfo(poolKey);
        uint256 fees1InitialWETH = fees1Initial;
        
        console2.log("Initial Fees - USDC:", fees0Initial);
        console2.log("Initial Fees - WETH:", fees1InitialWETH / 1e12, "wei");
        console2.log("");
        
        // Deploy SwapHelper
        SwapHelper swapHelper = new SwapHelper(poolManager);
        console2.log("SwapHelper deployed at:", address(swapHelper));
        
        // Approve helper
        weth.approve(address(swapHelper), type(uint256).max);
        usdc.approve(address(swapHelper), type(uint256).max);
        console2.log("Approved helper for WETH and USDC");
        console2.log("");
        
        // Check WETH balance
        uint256 wethBalance = weth.balanceOf(deployer);
        console2.log("WETH Balance:", wethBalance / 1e18, "WETH");
        
        // Calculate if we have enough WETH
        uint256 estimatedSwaps = TARGET_FEES_WETH / (SWAP_SIZE_WETH * 3000 / 1_000_000); // Fee = 0.3%
        uint256 wethNeeded = estimatedSwaps * SWAP_SIZE_WETH;
        
        if (wethBalance < wethNeeded) {
            console2.log("WARNING: May not have enough WETH!");
            console2.log("  Need approximately:", wethNeeded / 1e18, "WETH");
            console2.log("  Have:", wethBalance / 1e18, "WETH");
            console2.log("");
        }
        
        bytes memory hookData = "";
        bool zeroForOne = false; // Start with WETH -> USDC
        uint256 swapCount = 0;
        uint256 fees1Current = fees1InitialWETH;
        
        console2.log("=== Starting Swaps ===");
        console2.log("");
        
        while (fees1Current < TARGET_FEES_WETH && swapCount < MAX_SWAPS) {
            // Check if we have enough balance for swap
            if (zeroForOne) {
                // USDC -> WETH
                if (usdc.balanceOf(deployer) < SWAP_SIZE_WETH / 1e12) { // USDC has 6 decimals
                    console2.log("Insufficient USDC balance. Stopping.");
                    break;
                }
            } else {
                // WETH -> USDC
                if (weth.balanceOf(deployer) < SWAP_SIZE_WETH) {
                    console2.log("Insufficient WETH balance. Stopping.");
                    break;
                }
            }
            
            uint256 actualSwapAmount = SWAP_SIZE_WETH;
            if (zeroForOne) {
                actualSwapAmount = SWAP_SIZE_WETH / 1e12; // Convert to USDC decimals (6)
            }
            
            SwapParams memory swapParams = SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(actualSwapAmount), // Negative = exactInput
                sqrtPriceLimitX96: zeroForOne ? 
                    (TickMath.MIN_SQRT_PRICE + 1) : // USDC->WETH: price decreases
                    (TickMath.MAX_SQRT_PRICE - 1)   // WETH->USDC: price increases
            });
            
            try swapHelper.swap(poolKey, swapParams, hookData) returns (BalanceDelta delta) {
                swapCount++;
                
                // Check fees after swap
                (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
                fees1Current = fees1After;
                
                // Log every 50 swaps or when close to target
                if (swapCount % 50 == 0 || fees1Current >= TARGET_FEES_WETH * 90 / 100) {
                    console2.log("Swap", swapCount);
                    uint256 fees1Scaled = fees1Current / 1e12;
                    console2.log("Fees1:", fees1Scaled, "wei");
                    uint256 progress = (fees1Current * 100) / TARGET_FEES_WETH;
                    console2.log("Progress:", progress, "%");
                }
                
                // Alternate direction
                zeroForOne = !zeroForOne;
            } catch Error(string memory reason) {
                console2.log("Swap", swapCount + 1, "failed:", reason);
                break;
            } catch {
                console2.log("Swap", swapCount + 1, "failed with unknown error");
                break;
            }
        }
        
        vm.stopBroadcast();
        
        console2.log("");
        console2.log("=== Final Status ===");
        console2.log("Total swaps executed:", swapCount);
        console2.log("");
        
        // Get final fees
        (, uint256 fees0Final, uint256 fees1Final,,) = hook.getPoolInfo(poolKey);
        console2.log("Final Fees - USDC:", fees0Final);
        console2.log("Final Fees - WETH (wei):", fees1Final);
        console2.log("Target was: 0.0001 WETH (100000000000000 wei)");
        
        if (fees1Final >= TARGET_FEES_WETH) {
            console2.log("");
            console2.log("SUCCESS: Target fees reached!");
            console2.log("You can now try to execute compound.");
        } else {
            console2.log("");
            console2.log("Partial completion - fees not yet at target.");
            uint256 remaining = (TARGET_FEES_WETH - fees1Final) / 1e18;
            console2.log("Remaining:", remaining, "WETH needed");
        }
        
        console2.log("");
        console2.log("=== Done ===");
    }
}

