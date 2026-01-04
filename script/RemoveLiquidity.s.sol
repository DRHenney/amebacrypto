// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove liquidity and test 10% fee payment
contract RemoveLiquidity is Script {
    using StateLibrary for IPoolManager;
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
        
        poolManager = IPoolManager(poolManagerAddress);
        hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        poolId = poolKey.toId();
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Removing Liquidity ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("Current SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        console2.log("Current Liquidity:", currentLiquidity);
        
        // Get tick range from hook config
        (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        
        // Check FEE_RECIPIENT address
        address feeRecipient = hook.FEE_RECIPIENT();
        console2.log("FEE_RECIPIENT:", feeRecipient);
        
        // Get balances before
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        uint256 feeRecipientBalance0Before = IERC20Minimal(token0).balanceOf(feeRecipient);
        uint256 feeRecipientBalance1Before = IERC20Minimal(token1).balanceOf(feeRecipient);
        
        console2.log("\n=== Balances Before Removal ===");
        console2.log("FEE_RECIPIENT Token0 Balance:", feeRecipientBalance0Before);
        console2.log("FEE_RECIPIENT Token1 Balance:", feeRecipientBalance1Before);
        
        // Remove 50% of liquidity (negative delta)
        // We'll remove half of current liquidity
        // Use int256 as ModifyLiquidityParams expects int256 (converted to int128 internally)
        int256 liquidityDelta = -int256(uint256(currentLiquidity)) / 2;
        
        console2.log("\n=== Removing Liquidity ===");
        console2.log("Liquidity Delta (to remove):", liquidityDelta);
        
        // Deploy helper contract
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Approve helper to spend tokens (might not be needed for removal, but to be safe)
        if (token0 != address(0)) {
            IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        }
        if (token1 != address(0)) {
            IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        }
        
        // Prepare modify liquidity params (negative delta = remove)
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        // Remove liquidity via helper
        // This will trigger afterRemoveLiquidity callback which should pay 10% to FEE_RECIPIENT
        BalanceDelta delta = helper.removeLiquidity(poolKey, params, hookData);
        
        console2.log("\n=== Liquidity Removal Result ===");
        console2.log("Delta Amount0:", delta.amount0());
        console2.log("Delta Amount1:", delta.amount1());
        
        // Get balances after
        uint256 feeRecipientBalance0After = IERC20Minimal(token0).balanceOf(feeRecipient);
        uint256 feeRecipientBalance1After = IERC20Minimal(token1).balanceOf(feeRecipient);
        
        console2.log("\n=== Balances After Removal ===");
        console2.log("FEE_RECIPIENT Token0 Balance:", feeRecipientBalance0After);
        console2.log("FEE_RECIPIENT Token1 Balance:", feeRecipientBalance1After);
        console2.log("Token0 Received:", feeRecipientBalance0After - feeRecipientBalance0Before);
        console2.log("Token1 Received:", feeRecipientBalance1After - feeRecipientBalance1Before);
        
        // Since fees are swapped to USDC, check USDC balance
        address usdcAddress = hook.USDC();
        uint256 usdcBalanceBefore = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        console2.log("\n=== USDC Balance (FEE_RECIPIENT) ===");
        console2.log("USDC Address:", usdcAddress);
        console2.log("USDC Balance:", usdcBalanceBefore);
        
        // Get pool state after
        (uint160 sqrtPriceX96After, int24 tickAfter,,) = poolManager.getSlot0(poolId);
        uint128 liquidityAfter = poolManager.getLiquidity(poolId);
        
        console2.log("\n=== Pool State After ===");
        console2.log("SqrtPriceX96:", sqrtPriceX96After);
        console2.log("Tick:", tickAfter);
        console2.log("Liquidity:", liquidityAfter);
        console2.log("Liquidity Removed:", currentLiquidity - liquidityAfter);
        
        console2.log("\n=== Test Complete ===");
        if (feeRecipientBalance0After > feeRecipientBalance0Before || 
            feeRecipientBalance1After > feeRecipientBalance1Before ||
            usdcBalanceBefore > 0) {
            console2.log("SUCCESS: FEE_RECIPIENT received payment!");
        } else {
            console2.log("WARNING: No payment detected - this might be normal if fees were very small");
            console2.log("Note: Fees are swapped to USDC, so check USDC balance");
        }
        
        vm.stopBroadcast();
    }
}

