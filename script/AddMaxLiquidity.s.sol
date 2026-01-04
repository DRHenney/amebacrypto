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

/// @notice Script to add maximum liquidity to a pool
contract AddMaxLiquidity is Script {
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
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        
        // Set tick range around current price (full range)
        int24 tickSpacing = 60;
        int24 tickLower = TickMath.minUsableTick(tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(tickSpacing);
        
        // Get token balances
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        uint256 token0Balance = IERC20Minimal(token0).balanceOf(deployer);
        uint256 token1Balance = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("=== Adding Maximum Liquidity ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Token0:", token0);
        console2.log("Token1:", token1);
        console2.log("Token0 Balance:", token0Balance);
        console2.log("Token1 Balance:", token1Balance);
        console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        
        // Calculate optimal amounts based on current price
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
        console2.log("Token0 Amount to add:", maxToken0);
        console2.log("Token1 Amount to add:", maxToken1);
        console2.log("Liquidity:", liquidity);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        
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
        
        vm.stopBroadcast();
    }
}

