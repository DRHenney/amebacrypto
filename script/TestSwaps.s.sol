// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Script to test swaps and verify fee accumulation
contract TestSwaps is Script {
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
        
        // Get swap amount from env (in smallest units)
        uint256 swapAmount = vm.envUint("SWAP_AMOUNT"); // e.g., 1e18
        
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
        
        // Check initial fees
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Initial State ===");
        console2.log("Fees0 Before:", fees0Before);
        console2.log("Fees1 Before:", fees1Before);
        
        // Deploy helper contract
        SwapHelper helper = new SwapHelper(poolManager);
        console2.log("SwapHelper deployed at:", address(helper));
        
        // Approve helper to spend tokens
        if (!poolKey.currency0.isAddressZero()) {
            IERC20Minimal(Currency.unwrap(poolKey.currency0)).approve(address(helper), type(uint256).max);
        }
        if (!poolKey.currency1.isAddressZero()) {
            IERC20Minimal(Currency.unwrap(poolKey.currency1)).approve(address(helper), type(uint256).max);
        }
        
        bytes memory hookData = "";
        
        // Swap 1: Token0 -> Token1 (exactInput)
        console2.log("\n=== Swap 1: Token0 -> Token1 ===");
        console2.log("Amount:", swapAmount);
        
        SwapParams memory swapParams1 = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(swapAmount), // Negative = exactInput
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1 // Min price limit for USDC->WETH (price decreases)
        });
        
        BalanceDelta delta1 = helper.swap(poolKey, swapParams1, hookData);
        
        console2.log("Swap 1 Result:");
        console2.log("Delta Amount0:", delta1.amount0());
        console2.log("Delta Amount1:", delta1.amount1());
        
        // Check fees after first swap
        (, uint256 fees0After1, uint256 fees1After1,,) = hook.getPoolInfo(poolKey);
        console2.log("Fees0 After Swap1:", fees0After1);
        console2.log("Fees1 After Swap1:", fees1After1);
        console2.log("Accumulated Fee0:", fees0After1 - fees0Before);
        console2.log("Accumulated Fee1:", fees1After1 - fees1Before);
        
        // Swap 2: Token1 -> Token0 (smaller amount)
        console2.log("\n=== Swap 2: Token1 -> Token0 ===");
        uint256 swapAmount2 = swapAmount / 2;
        console2.log("Amount:", swapAmount2);
        
        SwapParams memory swapParams2 = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(swapAmount2), // Negative = exactInput
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1 // Max price limit for WETH->USDC (price increases)
        });
        
        BalanceDelta delta2 = helper.swap(poolKey, swapParams2, hookData);
        
        console2.log("Swap 2 Result:");
        console2.log("Delta Amount0:", delta2.amount0());
        console2.log("Delta Amount1:", delta2.amount1());
        
        // Check final fees
        (, uint256 fees0Final, uint256 fees1Final,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Final State ===");
        console2.log("Fees0 Final:", fees0Final);
        console2.log("Fees1 Final:", fees1Final);
        console2.log("Total Accumulated Fee0:", fees0Final);
        console2.log("Total Accumulated Fee1:", fees1Final);
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("\n=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        vm.stopBroadcast();
    }
}
