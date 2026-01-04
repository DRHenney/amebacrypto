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
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";

/// @notice Script to add concentrated liquidity to a pool
contract AddConcentratedLiquidity is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    IPoolManager public poolManager;
    PoolKey public poolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        poolManager = IPoolManager(poolManagerAddress);
        
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
        
        // Get current pool price
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        // Initialize pool if not initialized
        if (sqrtPriceX96 == 0) {
            console2.log("Pool not initialized. Initializing...");
            uint160 startingPrice = uint160(79228162514264337593543950336); // sqrt(1) * 2^96
            vm.startBroadcast(deployerPrivateKey);
            int24 tick = poolManager.initialize(poolKey, startingPrice);
            vm.stopBroadcast();
            console2.log("Pool initialized! Tick:", tick);
            sqrtPriceX96 = startingPrice;
        }
        
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        
        // Get concentration range from env (default: 10% = 0.1)
        // This means ±10% from current price
        uint256 concentrationBps = vm.envOr("CONCENTRATION_BPS", uint256(1000)); // 1000 = 10%
        if (concentrationBps > 10000) concentrationBps = 10000; // Max 100%
        
        // Calculate tick range
        // For ±10%, we need to calculate ticks that represent ±10% price change
        // Price change of ±10% means sqrtPrice change of ±(sqrt(1.1) - 1) ≈ ±0.0488
        // In ticks, this is approximately ±(log(1.1) / log(1.0001)) ≈ ±953 ticks
        // But we'll use a simpler approach: calculate based on percentage
        
        // Calculate tick range: ±concentration% from current price
        // Tick spacing is 60, so we need to round to nearest multiple of 60
        int24 tickSpacing = 60;
        
        // Calculate tick range based on percentage
        // For ±10%: log(1.1) / log(1.0001) ≈ 953 ticks
        // For ±X%: approximately ±(X/100) * 953 ticks
        // We use direct multiplication to avoid precision loss
        // ±10% (1000 bps) = 1000/100 = 10%, so 10 * 953 = 9530, then /100 = 95.3
        // To get proper range, we multiply by 953 directly and divide by 100
        uint24 tickRangeUint = uint24((concentrationBps * 953) / 100); // Direct calculation
        // Round to nearest multiple of tick spacing
        int24 tickRange = int24(uint24((tickRangeUint / uint24(tickSpacing)) * uint24(tickSpacing)));
        
        // Ensure minimum range (at least 900 ticks for ~10%)
        if (tickRange < 900) {
            tickRange = 900;
            // Round to tick spacing
            tickRange = (tickRange / int24(tickSpacing)) * int24(tickSpacing);
        }
        
        int24 tickLower = currentTick - tickRange;
        int24 tickUpper = currentTick + tickRange;
        
        // Ensure ticks are within bounds and aligned to tick spacing
        int24 minTick = TickMath.minUsableTick(tickSpacing);
        int24 maxTick = TickMath.maxUsableTick(tickSpacing);
        
        if (tickLower < minTick) tickLower = minTick;
        if (tickUpper > maxTick) tickUpper = maxTick;
        
        // Align to tick spacing
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
        
        // Get token balances
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        uint256 token0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Adding Concentrated Liquidity ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Token0:", token0);
        console2.log("Token1:", token1);
        console2.log("Token0 Balance:", token0Balance);
        console2.log("Token1 Balance:", token1Balance);
        console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        console2.log("Concentration (bps):", concentrationBps);
        console2.log("Concentration (%):", concentrationBps / 100);
        console2.log("Tick Range:", tickRange);
        
        // Calculate optimal amounts based on current price and concentrated range
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        
        // Calculate liquidity from available balances
        // This function calculates the maximum liquidity we can create with both tokens
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            token0Balance,
            token1Balance
        );
        
        // Calculate actual amounts needed for this liquidity
        (uint256 maxToken0, uint256 maxToken1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            liquidity
        );
        
        // Ensure we don't exceed balances (shouldn't happen, but safety check)
        if (maxToken0 > token0Balance) {
            maxToken0 = token0Balance;
        }
        if (maxToken1 > token1Balance) {
            maxToken1 = token1Balance;
        }
        
        console2.log("\n=== Calculated Amounts ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Token0 Amount to add:", maxToken0);
        console2.log("Token1 Amount to add:", maxToken1);
        console2.log("Liquidity:", liquidity);
        
        if (liquidity == 0) {
            console2.log("\nError: Cannot calculate liquidity with current balances and range!");
            revert("Invalid liquidity calculation");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy helper contract
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("\nHelper deployed at:", address(helper));
        
        // Approve helper to spend tokens
        if (token0 != address(0)) {
            IERC20Minimal(token0).approve(address(helper), type(uint256).max);
            console2.log("Approved helper for token0");
        }
        if (token1 != address(0)) {
            IERC20Minimal(token1).approve(address(helper), type(uint256).max);
            console2.log("Approved helper for token1");
        }
        
        // Prepare modify liquidity params
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(liquidity)),
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        // Add liquidity via helper
        BalanceDelta delta = helper.addLiquidity(poolKey, params, hookData);
        
        console2.log("\nLiquidity added successfully!");
        console2.log("Delta Amount0:", delta.amount0());
        console2.log("Delta Amount1:", delta.amount1());
        console2.log("Token0 used:", maxToken0);
        console2.log("Token1 used:", maxToken1);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        
        vm.stopBroadcast();
    }
}
