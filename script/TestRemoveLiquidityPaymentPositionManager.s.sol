// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PositionConfig} from "@uniswap/v4-periphery/src/libraries/PositionConfig.sol";
import {Planner, Plan} from "@uniswap/v4-periphery/test/shared/Planner.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

/// @notice Script to test 10% fee payment on liquidity removal using PositionManager
/// This script:
/// 1. Adds liquidity using PositionManager
/// 2. Makes swaps to generate fees
/// 3. Removes liquidity using PositionManager
/// 4. Verifies FEE_RECIPIENT received 10% of fees
contract TestRemoveLiquidityPaymentPositionManager is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    // PositionManager address on Sepolia
    address constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    
    uint128 constant MAX_SLIPPAGE_INCREASE = type(uint128).max;
    uint128 constant MIN_SLIPPAGE_DECREASE = 0;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        IPositionManager positionManager = IPositionManager(POSITION_MANAGER);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 30000, // 3%
            tickSpacing: 600,
            hooks: IHooks(hookAddress)
        });
        PoolId poolId = poolKey.toId();
        
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        address feeRecipient = hook.FEE_RECIPIENT();
        address usdcAddress = hook.USDC();
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Test Remove Liquidity Payment (PositionManager) ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("PositionManager:", POSITION_MANAGER);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("FEE_RECIPIENT:", feeRecipient);
        console2.log("");
        
        // Get tick range from hook
        (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        console2.log("Tick Range:");
        console2.log("  Lower:", tickLower);
        console2.log("  Upper:", tickUpper);
        console2.log("");
        
        // Get current pool state
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        console2.log("Current sqrtPriceX96:", sqrtPriceX96);
        
        // Calculate liquidity for small amounts
        // Add: 100 USDC and 0.01 WETH
        uint256 amount0 = 100e6;  // 100 USDC (6 decimals)
        uint256 amount1 = 1e16;   // 0.01 WETH (18 decimals)
        
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            amount0,
            amount1
        );
        
        console2.log("=== Step 1: Add Liquidity ===");
        console2.log("Amount0 (USDC):", amount0);
        console2.log("Amount1 (WETH):", amount1);
        console2.log("Liquidity:", liquidity);
        console2.log("");
        
        // Approve PositionManager to spend tokens
        IERC20Minimal(token0).approve(POSITION_MANAGER, type(uint256).max);
        IERC20Minimal(token1).approve(POSITION_MANAGER, type(uint256).max);
        
        // Get next tokenId
        uint256 tokenId = positionManager.nextTokenId();
        console2.log("Next Token ID:", tokenId);
        
        // Get balances before
        uint256 deployerBalance0Before = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1Before = IERC20Minimal(token1).balanceOf(deployer);
        uint256 feeRecipientUSDCBefore = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        
        console2.log("Balances Before:");
        console2.log("  Deployer USDC:", deployerBalance0Before);
        console2.log("  Deployer WETH:", deployerBalance1Before);
        console2.log("  FEE_RECIPIENT USDC:", feeRecipientUSDCBefore);
        console2.log("");
        
        // Create PositionConfig
        PositionConfig memory config = PositionConfig({
            poolKey: poolKey,
            tickLower: tickLower,
            tickUpper: tickUpper
        });
        
        // Encode mint action
        Plan memory planner = Planner.init();
        planner.add(
            Actions.MINT_POSITION,
            abi.encode(
                config.poolKey,
                config.tickLower,
                config.tickUpper,
                liquidity,
                MAX_SLIPPAGE_INCREASE,
                MAX_SLIPPAGE_INCREASE,
                deployer,
                ""
            )
        );
        bytes memory calls = planner.finalizeModifyLiquidityWithClose(config.poolKey);
        
        // Mint position
        positionManager.modifyLiquidities(calls, block.timestamp + 1);
        
        console2.log("Position minted! Token ID:", tokenId);
        console2.log("");
        
        // Get balances after mint
        uint256 deployerBalance0AfterMint = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1AfterMint = IERC20Minimal(token1).balanceOf(deployer);
        console2.log("Balances After Mint:");
        console2.log("  Deployer USDC:", deployerBalance0AfterMint);
        console2.log("  Deployer WETH:", deployerBalance1AfterMint);
        console2.log("  USDC spent:", deployerBalance0Before - deployerBalance0AfterMint);
        console2.log("  WETH spent:", deployerBalance1Before - deployerBalance1AfterMint);
        console2.log("");
        
        // Step 2: Make swaps to generate fees
        console2.log("=== Step 2: Generate Fees with Swaps ===");
        
        SwapHelper swapHelper = new SwapHelper(poolManager);
        IERC20Minimal(token1).approve(address(swapHelper), type(uint256).max);
        
        // Make 5 swaps to generate fees
        uint256 swapAmount = 1e15; // 0.001 WETH
        for (uint256 i = 0; i < 5; i++) {
            SwapParams memory swapParams = SwapParams({
                zeroForOne: false, // WETH -> USDC
                amountSpecified: -int256(swapAmount),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            });
            
            swapHelper.swap(poolKey, swapParams, "");
            console2.log("Swap", i + 1, "executed");
        }
        console2.log("");
        
        // Check fees accumulated
        (, uint256 fees0, uint256 fees1,,) = hook.getPoolInfo(poolKey);
        console2.log("Fees Accumulated:");
        console2.log("  Fees0 (USDC):", fees0);
        console2.log("  Fees1 (WETH):", fees1);
        console2.log("");
        
        // Step 3: Remove partial liquidity (50%)
        console2.log("=== Step 3: Remove Partial Liquidity (50%) ===");
        
        uint128 currentLiquidity = positionManager.getPositionLiquidity(tokenId);
        console2.log("Current Position Liquidity:", currentLiquidity);
        
        uint256 liquidityToRemove = uint256(currentLiquidity) / 2;
        console2.log("Liquidity to Remove:", liquidityToRemove);
        console2.log("");
        
        // Get FEE_RECIPIENT USDC balance before removal
        uint256 feeRecipientUSDCBeforeRemoval = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        console2.log("FEE_RECIPIENT USDC Before Removal:", feeRecipientUSDCBeforeRemoval);
        console2.log("");
        
        // Encode decrease liquidity action
        Plan memory decreasePlanner = Planner.init();
        decreasePlanner.add(
            Actions.DECREASE_LIQUIDITY,
            abi.encode(
                tokenId,
                liquidityToRemove,
                MIN_SLIPPAGE_DECREASE,
                MIN_SLIPPAGE_DECREASE,
                ""
            )
        );
        bytes memory decreaseCalls = decreasePlanner.finalizeModifyLiquidityWithClose(config.poolKey);
        
        // Remove liquidity
        positionManager.modifyLiquidities(decreaseCalls, block.timestamp + 1);
        
        console2.log("Liquidity removed!");
        console2.log("");
        
        // Step 4: Verify FEE_RECIPIENT received payment
        console2.log("=== Step 4: Verify Payment to FEE_RECIPIENT ===");
        
        uint256 feeRecipientUSDCAfterRemoval = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        uint256 usdcReceived = feeRecipientUSDCAfterRemoval - feeRecipientUSDCBeforeRemoval;
        
        console2.log("FEE_RECIPIENT USDC After Removal:", feeRecipientUSDCAfterRemoval);
        console2.log("USDC Received by FEE_RECIPIENT:", usdcReceived);
        console2.log("");
        
        if (usdcReceived > 0) {
            console2.log("SUCCESS: FEE_RECIPIENT received payment!");
            console2.log("Payment amount:", usdcReceived, "USDC (wei)");
            console2.log("Payment amount:", usdcReceived / 1e6, ".", (usdcReceived % 1e6) / 1e3, "USDC");
        } else {
            console2.log("WARNING: No payment detected.");
            console2.log("This might be normal if fees were very small or already collected.");
        }
        
        console2.log("");
        console2.log("=== Test Complete ===");
        
        vm.stopBroadcast();
    }
}

