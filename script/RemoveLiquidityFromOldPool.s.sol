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

/// @notice Script to remove liquidity from an old pool (by hook address)
contract RemoveLiquidityFromOldPool is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Get hook address from env or use a default old one
        // Default: oldest hook from documentation (0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540)
        address hookAddress = vm.envOr("OLD_HOOK_ADDRESS", address(0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540));
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Removendo Liquidez de Pool Antiga ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Deployer:", deployer);
        
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
        
        // Try to get tick range from hook if it's our hook type
        int24 tickLower = -887220;
        int24 tickUpper = 887220;
        
        // Try to get from hook config (only if it's our hook)
        try AutoCompoundHook(hookAddress).getPoolInfo(poolKey) returns (
            AutoCompoundHook.PoolConfig memory,
            uint256,
            uint256,
            int24 lower,
            int24 upper
        ) {
            if (lower != 0 || upper != 0) {
                tickLower = lower;
                tickUpper = upper;
                console2.log("Tick range obtido do hook");
            } else {
                console2.log("Hook retornou tick range zero, usando full range");
            }
        } catch {
            // If hook doesn't have getPoolInfo, use default full range
            console2.log("Hook nao tem getPoolInfo ou erro, usando range padrao (full range)");
        }
        
        console2.log("\n=== Range de Ticks ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Current Tick:", currentTick);
        
        // Target: get 0.03 WETH
        // Remove 60% of liquidity to ensure we get enough WETH
        // Use int128 for liquidityDelta as required by ModifyLiquidityParams
        int128 liquidityToRemove = int128(int256(uint256(currentLiquidity)) * 60 / 100);
        int256 liquidityDelta = -int256(liquidityToRemove);
        
        console2.log("\n=== Removendo Liquidez ===");
        console2.log("Target WETH: 0.03 WETH");
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
        console2.log("Target WETH: 0.03");
        
        if (wethReceived >= 0.03 ether) {
            console2.log("[SUCCESS] WETH recebido suficiente!");
        } else {
            console2.log("[INFO] WETH recebido menor que target, mas liquidez foi removida");
        }
        
        vm.stopBroadcast();
    }
}

