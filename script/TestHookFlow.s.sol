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
import {BalanceDelta, toBalanceDelta} from "lib/v4-core/src/types/BalanceDelta.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";
import {TickMath} from "lib/v4-core/src/libraries/TickMath.sol";

// Helper contract para unlock callback
contract UnlockHelper {
    function unlockCallback() external {
        // Nada – só pra deslock
    }
}

contract TestHookFlow is Script {
    uint160 constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey); // Ou hardcoded 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        vm.startBroadcast(privateKey);

        // Deploy novos tokens mock
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        
        console.log("USDC deployed at:", address(usdc));
        console.log("WETH deployed at:", address(weth));
        
        MockERC20 token0 = usdc;
        MockERC20 token1 = weth;

        // Deploy novo PoolManager
        PoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager deployed at:", address(poolManager));
        
        // Deploy helper para unlock callback
        UnlockHelper unlockHelper = new UnlockHelper();
        
        address hookAddress = vm.envOr("HOOK_ADDRESS", address(0xCd57fAB543256dd009A0432c43F027AD94b75540));
        require(hookAddress != address(0), "HOOK_ADDRESS not set");
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);

        // Crie key (ordene currencies - currency0 deve ser o endereço menor)
        Currency currency0 = Currency.wrap(address(token0 < token1 ? token0 : token1));
        Currency currency1 = Currency.wrap(address(token0 < token1 ? token1 : token0));
        
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // Initialize pool (se não feito) - usar sqrtPriceX96 correto
        try poolManager.initialize(key, SQRT_PRICE_1_1) {
            console.log("Pool initialized");
        } catch {
            console.log("Pool already initialized or failed");
        }

        // Mint tokens pro deployer
        token0.mint(deployer, 1000e6);
        token1.mint(deployer, 10e18);

        // Approve PoolManager
        token0.approve(address(poolManager), type(uint256).max);
        token1.approve(address(poolManager), type(uint256).max);

        // Calcular ticks apropriados
        int24 currentTick = TickMath.getTickAtSqrtPrice(SQRT_PRICE_1_1);
        int24 tickLower = (currentTick / 60) * 60 - 60; // Arredondar para múltiplo de tickSpacing
        int24 tickUpper = (currentTick / 60) * 60 + 60;

        // Add liquidity (delta positivo - sem lock)
        ModifyLiquidityParams memory addLiquidityParams = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(1000e6), // Positivo = adicionar liquidez
            salt: bytes32(0)
        });
        poolManager.modifyLiquidity(key, addLiquidityParams, "");
        console.log("Liquidity added");

        // Swap (acumula fees)
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true, // token0 para token1
            amountSpecified: -int256(10e6), // negativo = exact input (10 USDC)
            sqrtPriceLimitX96: 0 // sem limite de preço
        });
        
        poolManager.swap(key, swapParams, "");
        console.log("Swap executed");

        // Simule fees acumuladas no hook (pra testar afterRemoveLiquidity)
        // Nota: deal() não está disponível em Script, apenas em Test
        // Para simular fees, você precisaria fazer mint/transfer manual ou usar em testes
        // usdc.transfer(address(hook), 100e6); // 100 USDC fees (se você tiver tokens)
        // weth.transfer(address(hook), 1e18); // 1 WETH fees (se você tiver tokens)

        // Chame o callback manual (prank PoolManager)
        // Nota: afterRemoveLiquidity é uma função interna do hook e não pode ser chamada diretamente
        // Para testar isso, você precisaria fazer um removeLiquidity real na pool
        // ou criar um teste separado que use o padrão correto
        
        // Comentado porque não podemos chamar callbacks internos diretamente
        /*
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: 0,
            tickUpper: 0,
            liquidityDelta: 0,
            salt: bytes32(0)
        });
        
        BalanceDelta delta = toBalanceDelta(0, 0); // Delta zero
        BalanceDelta feesAccrued = toBalanceDelta(int128(uint128(100e6)), int128(uint128(1e18))); // Fees: 100 USDC + 1 WETH
        
        vm.prank(address(poolManager));
        hook.afterRemoveLiquidity(deployer, key, removeParams, delta, feesAccrued, "");
        */

        // Verifique pagamento 10% em USDC pra FEE_RECIPIENT (se houver)
        // console.log("USDC balance FEE_RECIPIENT:", usdc.balanceOf(hook.FEE_RECIPIENT()));

        vm.stopBroadcast();
    }
}

