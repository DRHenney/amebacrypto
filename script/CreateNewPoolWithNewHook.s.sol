// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to create new pool with new hook and configure it
contract CreateNewPoolWithNewHook is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    IPoolManager public poolManager;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        poolManager = IPoolManager(poolManagerAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Creating New Pool with New Hook ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("Token0:", token0Address);
        console2.log("Token1:", token1Address);
        console2.log("");
        
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
        
        // Step 1: Initialize pool
        console2.log("=== Step 1: Initializing Pool ===");
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        if (sqrtPriceX96 != 0) {
            console2.log("Pool already initialized!");
            console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        } else {
            // Use a starting price (1:1 ratio for simplicity, can be adjusted)
            uint160 startingPrice = uint160(79228162514264337593543950336); // sqrt(1) * 2^96
            int24 tick = poolManager.initialize(poolKey, startingPrice);
            console2.log("Pool initialized successfully!");
            console2.log("Initial Tick:", tick);
            sqrtPriceX96 = startingPrice;
        }
        console2.log("");
        
        // Step 2: Configure hook
        console2.log("=== Step 2: Configuring Hook ===");
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Enable pool
        hook.setPoolConfig(poolKey, true);
        console2.log("Pool config enabled");
        
        // Set tick range (concentrated range: ±10% from current price)
        int24 tickSpacing = 60;
        
        // Get current tick from pool
        (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        int24 currentTick = TickMath.getTickAtSqrtPrice(currentSqrtPriceX96);
        
        // Calculate tick range for ±10% concentration
        // For ±10%: log(1.1) / log(1.0001) ≈ 953 ticks
        // Using 9480 ticks for ±10% (more accurate)
        uint256 concentrationBps = 1000; // 10% = 1000 bps
        uint24 tickRangeUint = uint24((concentrationBps * 9480) / 10000); // 9480 ticks for ±10%
        int24 tickRange = int24(uint24((tickRangeUint / uint24(tickSpacing)) * uint24(tickSpacing)));
        
        // Ensure minimum range
        if (tickRange < 900) {
            tickRange = 900;
            tickRange = (tickRange / tickSpacing) * tickSpacing;
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
        
        hook.setPoolTickRange(poolKey, tickLower, tickUpper);
        console2.log("Tick range set - Lower:", tickLower);
        console2.log("Tick range set - Upper:", tickUpper);
        console2.log("Current Tick:", currentTick);
        console2.log("Range: +-10% (concentrated)");
        
        // Set token prices (approximate values for Sepolia)
        // USDC: $1, WETH: ~$3000
        hook.setTokenPricesUSD(poolKey, 1e6, 3000e18); // 1 USDC = $1, 1 WETH = $3000
        console2.log("Token prices set: USDC=$1, WETH=$3000");
        console2.log("");
        
        // Step 3: Add initial liquidity (optional)
        console2.log("=== Step 3: Adding Initial Liquidity (Optional) ===");
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        uint256 token0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("Deployer Token0 Balance:", token0Balance);
        console2.log("Deployer Token1 Balance:", token1Balance);
        
        if (token0Balance > 0 && token1Balance > 0) {
            // Use a portion of available balance (e.g., 50%)
            uint256 amount0ToAdd = token0Balance / 2;
            uint256 amount1ToAdd = token1Balance / 2;
            
            console2.log("Adding liquidity:");
            console2.log("Amount0:", amount0ToAdd);
            console2.log("Amount1:", amount1ToAdd);
            
            // Get current price
            (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
            int24 currentTick = TickMath.getTickAtSqrtPrice(currentSqrtPriceX96);
            
            // Calculate tick range (concentrated range: ±10% from current price)
            // For ±10%: approximately 9480 ticks
            int24 tickRange = 9480;
            tickRange = (tickRange / tickSpacing) * tickSpacing; // Round to tick spacing
            
            int24 tickLower = currentTick - tickRange;
            int24 tickUpper = currentTick + tickRange;
            
            // Ensure ticks are within bounds
            if (tickLower < minTick) tickLower = minTick;
            if (tickUpper > maxTick) tickUpper = maxTick;
            
            // Align to tick spacing
            tickLower = (tickLower / tickSpacing) * tickSpacing;
            tickUpper = (tickUpper / tickSpacing) * tickSpacing;
            
            console2.log("Tick range - Lower:", tickLower);
            console2.log("Tick range - Upper:", tickUpper);
            
            // Calculate liquidity from amounts
            uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
            uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
            
            uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                currentSqrtPriceX96,
                sqrtPriceAX96,
                sqrtPriceBX96,
                amount0ToAdd,
                amount1ToAdd
            );
            
            console2.log("Calculated liquidity:", liquidity);
            
            if (liquidity > 0) {
                // Approve pool manager
                IERC20Minimal(token0).approve(address(poolManager), type(uint256).max);
                IERC20Minimal(token1).approve(address(poolManager), type(uint256).max);
                
                ModifyLiquidityParams memory params = ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int128(int256(uint256(liquidity))),
                    salt: bytes32(0)
                });
                
                (BalanceDelta delta,) = poolManager.modifyLiquidity(poolKey, params, "");
                console2.log("Liquidity added!");
                console2.log("Delta Amount0:", delta.amount0());
                console2.log("Delta Amount1:", delta.amount1());
            } else {
                console2.log("WARNING: Calculated liquidity is 0, skipping liquidity addition");
            }
        } else {
            console2.log("Insufficient tokens to add liquidity");
            console2.log("You can add liquidity later using AddConcentratedLiquidity.s.sol");
        }
        console2.log("");
        
        // Step 4: Summary
        console2.log("=== Summary ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("Pool initialized and configured!");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Add liquidity using: script/AddConcentratedLiquidity.s.sol");
        console2.log("2. Configure CompoundHelper when ready to use real fees");
        console2.log("3. Start accumulating fees with swaps");
        
        vm.stopBroadcast();
    }
}

