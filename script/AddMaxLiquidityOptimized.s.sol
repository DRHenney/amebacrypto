// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";

/// @notice Script to add maximum liquidity with range ±10% (concentrated)
/// This automatically optimizes the token ratio based on current price
contract AddMaxLiquidityOptimized is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
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
        
        PoolId poolId = poolKey.toId();
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Adding Maximum Liquidity (Concentrated +-10%) ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        console2.log("Current Tick:", currentTick);
        console2.log("Current SqrtPriceX96:", sqrtPriceX96);
        
        // Get token balances
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        uint256 token0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("");
        console2.log("=== Initial Balances ===");
        console2.log("Token0 Balance:", token0Balance);
        console2.log("Token1 Balance:", token1Balance);
        console2.log("");
        
        // Calculate concentrated range (±10%)
        int24 tickSpacing = 60;
        uint256 concentrationBps = 1000; // 10% = 1000 bps
        uint24 tickRangeUint = uint24((concentrationBps * 9480) / 10000); // 9480 ticks for ±10%
        int24 tickRange = int24(uint24((tickRangeUint / uint24(tickSpacing)) * uint24(tickSpacing)));
        
        if (tickRange < 900) {
            tickRange = 900;
            tickRange = (tickRange / tickSpacing) * tickSpacing;
        }
        
        int24 tickLower = currentTick - tickRange;
        int24 tickUpper = currentTick + tickRange;
        
        // Ensure ticks are within bounds and aligned
        int24 minTick = TickMath.minUsableTick(tickSpacing);
        int24 maxTick = TickMath.maxUsableTick(tickSpacing);
        
        if (tickLower < minTick) tickLower = minTick;
        if (tickUpper > maxTick) tickUpper = maxTick;
        
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
        
        console2.log("=== Tick Range Configuration ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Range: +-10% concentrated");
        console2.log("");
        
        // Calculate sqrt prices
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        
        // Calculate maximum liquidity we can create with current balances
        // This automatically optimizes the token ratio based on current price
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
        
        console2.log("=== Calculated Amounts ===");
        console2.log("Liquidity to add:", liquidity);
        console2.log("Token0 Amount:", maxToken0);
        console2.log("Token1 Amount:", maxToken1);
        console2.log("");
        
        if (liquidity == 0) {
            console2.log("ERROR: Cannot calculate liquidity with current balances!");
            vm.stopBroadcast();
            return;
        }
        
        // Deploy helper for adding liquidity
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Approve helper
        IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        console2.log("Approved helper for both tokens");
        console2.log("");
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int128(int256(uint256(liquidity))),
            salt: bytes32(0)
        });
        
        console2.log("=== Adding Liquidity ===");
        BalanceDelta addDelta = helper.addLiquidity(poolKey, params, "");
        
        console2.log("");
        console2.log("=== Liquidity Added Successfully ===");
        console2.log("Delta Amount0:", addDelta.amount0());
        console2.log("Delta Amount1:", addDelta.amount1());
        
        // Get final balances
        uint256 finalToken0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 finalToken1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("");
        console2.log("=== Final Balances ===");
        console2.log("Token0 Balance:", finalToken0Balance);
        console2.log("Token1 Balance:", finalToken1Balance);
        console2.log("Token0 Used:", token0Balance - finalToken0Balance);
        console2.log("Token1 Used:", token1Balance - finalToken1Balance);
        
        // Get pool state after
        uint128 poolLiquidity = poolManager.getLiquidity(poolId);
        console2.log("");
        console2.log("=== Pool State After ===");
        console2.log("Pool Liquidity:", poolLiquidity);
        
        vm.stopBroadcast();
    }
}
