// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "lib/v4-core/src/PoolManager.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "lib/v4-core/src/types/PoolOperation.sol";
import {SwapParams} from "lib/v4-core/src/types/PoolOperation.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {TickMath} from "lib/v4-core/src/libraries/TickMath.sol";

contract TestFullFlow is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Tokens mock (use os addresses do deploy anterior ou redeploy)
        // Você pode definir via variáveis de ambiente ou usar os endereços diretamente
        address usdcAddress = vm.envOr("USDC_ADDRESS", address(0));
        address wethAddress = vm.envOr("WETH_ADDRESS", address(0));
        
        require(usdcAddress != address(0), "USDC_ADDRESS not set");
        require(wethAddress != address(0), "WETH_ADDRESS not set");
        
        MockERC20 token0 = MockERC20(usdcAddress);
        MockERC20 token1 = MockERC20(wethAddress);

        // PoolManager (use o deployado ou new)
        address poolManagerAddress = vm.envOr("POOL_MANAGER_ADDRESS", address(0));
        require(poolManagerAddress != address(0), "POOL_MANAGER_ADDRESS not set");
        PoolManager poolManager = PoolManager(payable(poolManagerAddress));

        // Seu hook (address do deploy anterior)
        address hookAddress = vm.envOr("HOOK_ADDRESS", address(0xCd57fAB543256dd009A0432c43F027AD94b75540));
        require(hookAddress != address(0), "HOOK_ADDRESS not set");
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);

        // Crie PoolKey
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // Initialize pool com sqrtPriceX96 (preço inicial)
        // sqrtPriceX96 = sqrt(price) * 2^96
        // Para 1:1, usar aproximadamente 2^96
        uint160 sqrtPriceX96 = uint160(79228162514264337593543950336); // ~1:1 price
        poolManager.initialize(key, sqrtPriceX96);

        console.log("Pool initialized");

        // Add liquidity (ex: 1000 USDC + 1 WETH)
        // Primeiro, mint tokens para o script
        token0.mint(address(this), 1000e6);
        token1.mint(address(this), 1e18);
        
        // Approve tokens para o PoolManager
        token0.approve(address(poolManager), 1000e6);
        token1.approve(address(poolManager), 1e18);

        // Calcular ticks apropriados (range de liquidez)
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        int24 tickLower = (currentTick / 60) * 60 - 60; // Arredondar para múltiplo de tickSpacing
        int24 tickUpper = (currentTick / 60) * 60 + 60;

        // ModifyLiquidityParams precisa de salt também
        ModifyLiquidityParams memory liquidityParams = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: 1000e6, // Aproximação simples - em produção use LiquidityAmounts
            salt: bytes32(0)
        });

        poolManager.modifyLiquidity(key, liquidityParams, "");

        console.log("Liquidity added");

        // Swap (acumula fees)
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true, // token0 para token1
            amountSpecified: -int256(10e6), // negativo = exact input (10 USDC)
            sqrtPriceLimitX96: 0 // sem limite de preço
        });

        poolManager.swap(key, swapParams, "");

        console.log("Swap executed");

        // Remove liquidity (dispara afterRemoveLiquidity – pagamento 10% pra você)
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int256(1000e6), // negativo = remover
            salt: bytes32(0)
        });

        poolManager.modifyLiquidity(key, removeParams, "");

        console.log("Liquidity removed");

        // Verificar balance do FEE_RECIPIENT
        address feeRecipient = hook.FEE_RECIPIENT();
        uint256 usdcBalance = token0.balanceOf(feeRecipient);
        uint256 wethBalance = token1.balanceOf(feeRecipient);

        console.log("USDC balance FEE_RECIPIENT:", usdcBalance);
        console.log("WETH balance FEE_RECIPIENT:", wethBalance);
        console.log("FEE_RECIPIENT address:", feeRecipient);

        vm.stopBroadcast();
    }
}

