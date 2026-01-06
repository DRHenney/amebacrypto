// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove 100% of liquidity from the current pool (fee 3%, tickSpacing 600)
contract RemoveAllLiquidityCurrentPool is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey for current pool (fee 3%, tickSpacing 600)
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
        
        console2.log("=== Remove 100% Liquidity from Current Pool ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("Fee: 3%");
        console2.log("Tick Spacing: 600");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = StateLibrary.getSlot0(poolManager, poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("=== Pool State Before ===");
        console2.log("SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        console2.log("Current Liquidity:", currentLiquidity);
        console2.log("");
        
        if (currentLiquidity == 0) {
            console2.log("Pool ja esta vazia (liquidez = 0)");
            vm.stopBroadcast();
            return;
        }
        
        // Get tick range from hook config
        (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // Check FEE_RECIPIENT address
        address feeRecipient = hook.FEE_RECIPIENT();
        console2.log("FEE_RECIPIENT:", feeRecipient);
        console2.log("");
        
        // Get balances before
        uint256 balance0Before = IERC20Minimal(token0).balanceOf(deployer);
        uint256 balance1Before = IERC20Minimal(token1).balanceOf(deployer);
        uint256 feeRecipientUSDCBefore = IERC20Minimal(token0).balanceOf(feeRecipient);
        address usdcAddress = hook.USDC();
        uint256 feeRecipientUSDCRealBefore = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        
        console2.log("=== Balances Before ===");
        console2.log("Token0 (USDC) Balance:", balance0Before);
        console2.log("Token1 (WETH) Balance:", balance1Before);
        console2.log("Token1 (WETH) Balance (formatted):", balance1Before / 1e18, ".", (balance1Before % 1e18) / 1e12);
        console2.log("FEE_RECIPIENT USDC Balance (token0):", feeRecipientUSDCBefore);
        console2.log("FEE_RECIPIENT USDC Balance (real USDC):", feeRecipientUSDCRealBefore);
        console2.log("");
        
        // Remove 100% of liquidity (negative delta equal to current liquidity)
        int128 liquidityDelta = -int128(currentLiquidity);
        
        console2.log("=== Removing Liquidity ===");
        console2.log("Liquidity Delta (to remove):", liquidityDelta);
        console2.log("Removing 100% of liquidity");
        console2.log("");
        
        // Deploy helper contract
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("LiquidityHelper deployed at:", address(helper));
        console2.log("");
        
        // Approve helper to spend tokens (needed for settlement)
        IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        
        // Prepare modify liquidity params (negative delta = remove)
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        // Remove liquidity via helper
        console2.log("Executando remocao de liquidez...");
        BalanceDelta delta = helper.removeLiquidity(poolKey, params, hookData);
        
        console2.log("");
        console2.log("=== Liquidity Removal Result ===");
        console2.log("Delta Amount0:", delta.amount0());
        console2.log("Delta Amount1:", delta.amount1());
        console2.log("");
        
        // Get balances after
        uint256 balance0After = IERC20Minimal(token0).balanceOf(deployer);
        uint256 balance1After = IERC20Minimal(token1).balanceOf(deployer);
        uint256 feeRecipientUSDCAfter = IERC20Minimal(token0).balanceOf(feeRecipient);
        uint256 feeRecipientUSDCRealAfter = IERC20Minimal(usdcAddress).balanceOf(feeRecipient);
        
        console2.log("=== Balances After ===");
        console2.log("Token0 (USDC) Balance:", balance0After);
        console2.log("Token1 (WETH) Balance:", balance1After);
        console2.log("Token1 (WETH) Balance (formatted):", balance1After / 1e18, ".", (balance1After % 1e18) / 1e12);
        console2.log("FEE_RECIPIENT USDC Balance (token0):", feeRecipientUSDCAfter);
        console2.log("FEE_RECIPIENT USDC Balance (real USDC):", feeRecipientUSDCRealAfter);
        console2.log("");
        
        console2.log("=== Balance Changes ===");
        console2.log("Token0 (USDC) Received:", int256(balance0After) - int256(balance0Before));
        console2.log("Token1 (WETH) Received:", int256(balance1After) - int256(balance1Before));
        console2.log("");
        
        console2.log("=== FEE_RECIPIENT Payment ===");
        if (feeRecipientUSDCRealAfter > feeRecipientUSDCRealBefore) {
            uint256 payment = feeRecipientUSDCRealAfter - feeRecipientUSDCRealBefore;
            console2.log("SUCCESS: FEE_RECIPIENT received", payment, "USDC (10% of fees)");
        } else {
            console2.log("No payment detected - fees may have been very small or already paid");
        }
        console2.log("");
        
        // Get pool state after
        (uint160 sqrtPriceX96After, int24 tickAfter,,) = StateLibrary.getSlot0(poolManager, poolId);
        uint128 liquidityAfter = poolManager.getLiquidity(poolId);
        
        console2.log("=== Pool State After ===");
        console2.log("SqrtPriceX96:", sqrtPriceX96After);
        console2.log("Tick:", tickAfter);
        console2.log("Liquidity:", liquidityAfter);
        console2.log("");
        
        if (liquidityAfter == 0) {
            console2.log("SUCCESS: 100% da liquidez foi removida!");
        } else {
            console2.log("WARNING: Ainda ha liquidez na pool:", liquidityAfter);
            console2.log("Liquidez restante:", liquidityAfter);
        }
        
        vm.stopBroadcast();
    }
}

