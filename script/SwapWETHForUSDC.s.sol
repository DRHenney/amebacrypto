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

/// @notice Script to swap WETH for USDC to get more USDC tokens
contract SwapWETHForUSDC is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
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
        
        // Amount of WETH to swap (default: 0.001 WETH - smaller amount to avoid liquidity issues)
        uint256 wethAmount = vm.envOr("SWAP_WETH_AMOUNT", uint256(1000000000000000)); // 0.001 WETH
        
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
        
        // Check balances before
        IERC20Minimal weth = IERC20Minimal(Currency.unwrap(poolKey.currency1));
        IERC20Minimal usdc = IERC20Minimal(Currency.unwrap(poolKey.currency0));
        
        uint256 wethBalanceBefore = weth.balanceOf(deployer);
        uint256 usdcBalanceBefore = usdc.balanceOf(deployer);
        
        console2.log("=== Swapping WETH for USDC ===");
        console2.log("Your address:", deployer);
        console2.log("WETH balance before:", wethBalanceBefore);
        console2.log("USDC balance before:", usdcBalanceBefore);
        console2.log("WETH amount to swap:", wethAmount);
        console2.log("WETH amount to swap (ETH):", wethAmount / 1e18, "ETH");
        
        if (wethBalanceBefore < wethAmount) {
            console2.log("\nERROR: Insufficient WETH balance!");
            console2.log("You have:", wethBalanceBefore);
            console2.log("You need:", wethAmount);
            console2.log("Please wrap more ETH to WETH first using WrapETH.s.sol");
            return;
        }
        
        // Check initial fees
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Pool Fees Before ===");
        console2.log("Fees0 (USDC):", fees0Before);
        console2.log("Fees1 (WETH):", fees1Before);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy helper contract
        SwapHelper helper = new SwapHelper(poolManager);
        console2.log("\nSwapHelper deployed at:", address(helper));
        
        // Approve helper to spend WETH
        weth.approve(address(helper), type(uint256).max);
        console2.log("Approved helper for WETH");
        
        bytes memory hookData = "";
        
        // Swap: WETH -> USDC (Token1 -> Token0)
        console2.log("\n=== Executing Swap ===");
        console2.log("Direction: WETH -> USDC");
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: false, // false = Token1 -> Token0 (WETH -> USDC)
            amountSpecified: -int256(wethAmount), // Negative = exactInput
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1 // Max price limit for WETH->USDC (price increases)
        });
        
        BalanceDelta delta = helper.swap(poolKey, swapParams, hookData);
        
        console2.log("\nSwap Result:");
        console2.log("Delta Amount0 (USDC received):", delta.amount0());
        console2.log("Delta Amount1 (WETH sent):", delta.amount1());
        
        // Check balances after
        uint256 wethBalanceAfter = weth.balanceOf(deployer);
        uint256 usdcBalanceAfter = usdc.balanceOf(deployer);
        
        console2.log("\n=== Balances After ===");
        console2.log("WETH balance after:", wethBalanceAfter);
        console2.log("USDC balance after:", usdcBalanceAfter);
        console2.log("WETH spent:", wethBalanceBefore - wethBalanceAfter);
        console2.log("USDC received:", usdcBalanceAfter - usdcBalanceBefore);
        
        // Check fees after swap
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Pool Fees After ===");
        console2.log("Fees0 (USDC):", fees0After);
        console2.log("Fees1 (WETH):", fees1After);
        console2.log("Fees accumulated (USDC):", fees0After - fees0Before);
        console2.log("Fees accumulated (WETH):", fees1After - fees1Before);
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("\n=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        console2.log("\n=== Swap Complete! ===");
        console2.log("You now have more USDC to test swaps!");
        
        vm.stopBroadcast();
    }
}

