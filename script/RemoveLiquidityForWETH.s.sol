// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove liquidity to get approximately 0.03 WETH
contract RemoveLiquidityForWETH is Script {
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
        
        address deployer = vm.addr(deployerPrivateKey);
        
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
        
        console2.log("=== Removendo Liquidez para obter 0.03 WETH ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("Deployer:", deployer);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("\n=== Estado Atual da Pool ===");
        console2.log("Current SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", currentTick);
        console2.log("Current Liquidity:", currentLiquidity);
        
        if (currentLiquidity == 0) {
            console2.log("\nAVISO: A pool nao tem liquidez!");
            vm.stopBroadcast();
            return;
        }
        
        // Get token addresses
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        // Get balances before removal
        uint256 deployerBalance0Before = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1Before = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("\n=== Saldos Antes da Remocao ===");
        console2.log("Deployer Token0 (USDC) Balance:", deployerBalance0Before);
        console2.log("Deployer Token1 (WETH) Balance:", deployerBalance1Before);
        console2.log("Deployer Token1 (WETH) Balance (WETH):", deployerBalance1Before / 1e18);
        
        // Get tick range from hook config (or use the range from last addition)
        (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        
        // If hook range is too wide, use the range from last addition
        if (tickLower == -887220 && tickUpper == 887220) {
            tickLower = 404940;
            tickUpper = 423900;
            console2.log("\nUsando range da ultima adicao de liquidez");
        }
        
        console2.log("\n=== Range de Ticks ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Current Tick:", currentTick);
        
        // Target: get 0.03 WETH
        // We'll remove a percentage of liquidity that should be sufficient
        // Since we don't know the exact ratio, we'll remove a conservative amount (50-70%)
        // This should be enough for 0.03 WETH if there's sufficient liquidity
        uint256 targetWETH = 0.03 ether; // 0.03 WETH in wei
        
        // Remove 60% of liquidity as a starting point (should be enough for 0.03 WETH if pool has liquidity)
        // We use a higher percentage to ensure we get enough WETH
        uint256 liquidityToRemove = (uint256(currentLiquidity) * 60) / 100;
        int256 liquidityDelta = -int256(liquidityToRemove);
        
        console2.log("\n=== Removendo Liquidez ===");
        console2.log("Target WETH (wei):", targetWETH);
        console2.log("Target WETH (WETH):", targetWETH / 1e18);
        console2.log("Liquidity to remove:", liquidityToRemove);
        console2.log("Liquidity Delta (to remove):", liquidityDelta);
        console2.log("Percentage of liquidity: 60%");
        
        // Deploy helper contract
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Prepare modify liquidity params (negative delta = remove)
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        // Remove liquidity via helper
        BalanceDelta delta = helper.removeLiquidity(poolKey, params, hookData);
        
        console2.log("\n=== Resultado da Remocao ===");
        console2.log("Delta Amount0:", delta.amount0());
        console2.log("Delta Amount1:", delta.amount1());
        
        // Get balances after removal
        uint256 deployerBalance0After = IERC20Minimal(token0).balanceOf(deployer);
        uint256 deployerBalance1After = IERC20Minimal(token1).balanceOf(deployer);
        
        console2.log("\n=== Saldos Depois da Remocao ===");
        console2.log("Deployer Token0 (USDC) Balance:", deployerBalance0After);
        console2.log("Deployer Token1 (WETH) Balance:", deployerBalance1After);
        
        uint256 usdcReceived = deployerBalance0After - deployerBalance0Before;
        uint256 wethReceived = deployerBalance1After - deployerBalance1Before;
        
        console2.log("\n=== Tokens Recebidos ===");
        console2.log("USDC Recebido (wei):", usdcReceived);
        console2.log("WETH Recebido (wei):", wethReceived);
        console2.log("WETH Recebido (WETH):", wethReceived / 1e18);
        
        console2.log("\n=== Resumo ===");
        console2.log("WETH recebido:", wethReceived / 1e18);
        console2.log("Target WETH:", targetWETH / 1e18);
        
        if (wethReceived >= targetWETH) {
            console2.log("[SUCCESS] WETH recebido suficiente!");
        } else {
            console2.log("[INFO] WETH recebido menor que target, mas liquidez foi removida");
            console2.log("Voce pode remover mais liquidez se necessario");
        }
        
        vm.stopBroadcast();
    }
}

