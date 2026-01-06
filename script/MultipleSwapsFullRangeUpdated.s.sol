// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script to perform multiple swaps to generate fees in the full range pool (fee 3%, tickSpacing 600)
contract MultipleSwapsFullRangeUpdated is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Get number of swaps from env (default: 100)
        uint256 numSwaps = vm.envOr("NUM_SWAPS", uint256(100));
        
        // Get whether to alternate directions (default: true)
        bool alternateDirections = vm.envOr("ALTERNATE_DIRECTIONS", true);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey for full range pool (fee 3%, tickSpacing 600)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 30000, // 3% - full range pool
            tickSpacing: 600, // tickSpacing for 3% fee
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        // Get token addresses
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        console2.log("=== Multiple Swaps to Generate Fees (Updated Pool) ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Fee: 3%");
        console2.log("Tick Spacing: 600");
        console2.log("Number of swaps:", numSwaps);
        console2.log("Alternate directions:", alternateDirections);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SwapHelper
        SwapHelper swapHelper = new SwapHelper(poolManager);
        console2.log("SwapHelper deployed at:", address(swapHelper));
        
        // Get initial balances
        uint256 token0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Initial Balances ===");
        console2.log("Token0 (USDC) Balance:", token0Balance);
        console2.log("Token1 (WETH) Balance:", token1Balance);
        console2.log("Token1 (WETH) Balance (formatted):", token1Balance / 1e18, ".", (token1Balance % 1e18) / 1e12);
        console2.log("");
        
        // Determine swap amounts (small amounts to ensure success)
        // For USDC (6 decimals): use 0.5 USDC = 500000
        // For WETH (18 decimals): use 0.002 WETH = 2000000000000000
        uint256 swapAmount0 = 500000; // 0.5 USDC
        uint256 swapAmount1 = 2000000000000000; // 0.002 WETH
        
        // Determine initial swap direction (token0 < token1, so token0 is USDC, token1 is WETH)
        // Start with WETH -> USDC (zeroForOne = false, because token1 -> token0)
        bool zeroForOne = false; // Start with token1 (WETH) -> token0 (USDC)
        
        // Approve SwapHelper to spend tokens
        if (token0Balance > 0) {
            IERC20Minimal(token0).approve(address(swapHelper), type(uint256).max);
        }
        if (token1Balance > 0) {
            IERC20Minimal(token1).approve(address(swapHelper), type(uint256).max);
        }
        console2.log("Approved SwapHelper for both tokens");
        console2.log("");
        
        uint256 successfulSwaps = 0;
        uint256 failedSwaps = 0;
        
        console2.log("=== Executing Swaps ===");
        console2.log("");
        
        for (uint256 i = 0; i < numSwaps; i++) {
            // Get current balances before swap
            uint256 currentBalance0 = IERC20Minimal(token0).balanceOf(deployer);
            uint256 currentBalance1 = IERC20Minimal(token1).balanceOf(deployer);
            
            // Determine swap direction and amount
            uint256 swapAmount;
            if (alternateDirections) {
                // Alternate direction each swap
                zeroForOne = (i % 2 == 1); // Even swaps: WETH->USDC (false), Odd swaps: USDC->WETH (true)
                swapAmount = zeroForOne ? swapAmount0 : swapAmount1;
                
                // Check if we have enough balance for this direction
                uint256 currentBalance = zeroForOne ? currentBalance0 : currentBalance1;
                if (currentBalance < swapAmount) {
                    // Switch direction if insufficient balance
                    zeroForOne = !zeroForOne;
                    swapAmount = zeroForOne ? swapAmount0 : swapAmount1;
                    currentBalance = zeroForOne ? currentBalance0 : currentBalance1;
                }
                
                if (currentBalance < swapAmount) {
                    console2.log("Swap", i + 1, ": Still insufficient balance, skipping");
                    failedSwaps++;
                    continue;
                }
            } else {
                // Always swap in the same direction (WETH -> USDC)
                zeroForOne = false;
                swapAmount = swapAmount1;
                
                if (currentBalance1 < swapAmount) {
                    console2.log("Swap", i + 1, ": Insufficient WETH balance, skipping");
                    failedSwaps++;
                    continue;
                }
            }
            
            // Prepare swap params
            SwapParams memory swapParams = SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(swapAmount),
                sqrtPriceLimitX96: zeroForOne ? (TickMath.MIN_SQRT_PRICE + 1) : (TickMath.MAX_SQRT_PRICE - 1)
            });
            
            // Execute swap
            bytes memory hookData = "";
            try swapHelper.swap(poolKey, swapParams, hookData) returns (BalanceDelta delta) {
                successfulSwaps++;
                if ((i + 1) % 10 == 0 || i == 0) {
                    string memory direction = zeroForOne ? "USDC->WETH" : "WETH->USDC";
                    console2.log("Swap", i + 1, ": Success - direction:", direction);
                }
            } catch Error(string memory swapError) {
                failedSwaps++;
                console2.log("Swap", i + 1, ": Failed -", swapError);
            } catch (bytes memory) {
                failedSwaps++;
                console2.log("Swap", i + 1, ": Failed - Low level error");
            }
        }
        
        console2.log("");
        console2.log("=== Swap Summary ===");
        console2.log("Total swaps attempted:", numSwaps);
        console2.log("Successful swaps:", successfulSwaps);
        console2.log("Failed swaps:", failedSwaps);
        console2.log("");
        
        // Get final balances
        uint256 token0BalanceAfter = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1BalanceAfter = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Final Balances ===");
        console2.log("Token0 (USDC) Balance:", token0BalanceAfter);
        console2.log("Token1 (WETH) Balance:", token1BalanceAfter);
        console2.log("Token1 (WETH) Balance (formatted):", token1BalanceAfter / 1e18, ".", (token1BalanceAfter % 1e18) / 1e12);
        console2.log("");
        console2.log("Token0 (USDC) Change:", int256(token0BalanceAfter) - int256(token0Balance));
        console2.log("Token1 (WETH) Change:", int256(token1BalanceAfter) - int256(token1Balance));
        console2.log("");
        
        vm.stopBroadcast();
        
        console2.log("=== Fees Generated! ===");
        console2.log("Fees have been accumulated in the hook.");
        console2.log("");
        
        // Check accumulated fees and compound status
        console2.log("=== Checking Accumulated Fees ===");
        (AutoCompoundHook.PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = 
            hook.getPoolInfo(poolKey);
        
        console2.log("Fees0 (USDC):", fees0);
        console2.log("Fees1 (WETH):", fees1);
        
        // Format fees for better readability
        uint256 fees0Whole = fees0 / 1e6;
        uint256 fees0Decimal = fees0 % 1e6;
        console2.log("Fees0 (USDC) formatted:", fees0Whole, ".", fees0Decimal);
        
        uint256 fees1Whole = fees1 / 1e18;
        uint256 fees1Decimal = (fees1 % 1e18) / 1e12;
        console2.log("Fees1 (WETH) formatted:", fees1Whole, ".", fees1Decimal);
        console2.log("");
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        
        console2.log("=== Compound Status ===");
        console2.log("Can Execute Compound:", canCompound);
        if (!canCompound) {
            console2.log("Reason:", reason);
            if (timeUntilNext > 0) {
                uint256 hoursRemaining = timeUntilNext / 3600;
                uint256 minutesRemaining = (timeUntilNext % 3600) / 60;
                console2.log("Time Until Next (hours):", hoursRemaining);
                console2.log("Time Until Next (minutes):", minutesRemaining);
                console2.log("Time Until Next (seconds):", timeUntilNext);
            }
        }
        console2.log("Fees Value (USD):", feesValueUSD / 1e18);
        console2.log("Gas Cost (USD):", gasCostUSD / 1e18);
        console2.log("");
        
        if (canCompound) {
            console2.log("Compound pode ser executado agora!");
        } else {
            console2.log("Compound nao pode ser executado ainda.");
            if (timeUntilNext > 0) {
                console2.log("Aguarde o tempo restante antes de tentar novamente.");
            }
        }
    }
}

