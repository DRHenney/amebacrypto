// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract TestPayment10Percent is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Deploy novos tokens mock
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 weth = new MockERC20("WETH", "WETH", 18);
        
        console.log("USDC deployed at:", address(usdc));
        console.log("WETH deployed at:", address(weth));

        // Addresses do seu deploy local (ou use os novos tokens)
        address hookAddr = vm.envOr("HOOK_ADDRESS", address(0xCd57fAB543256dd009A0432c43F027AD94b75540)); // Seu hook
        address poolManagerAddr = vm.envOr("POOL_MANAGER_ADDRESS", address(0x0165878A594ca255338adfa4d48449f69242Eb8F)); // PoolManager
        
        require(hookAddr != address(0), "HOOK_ADDRESS not set");
        require(poolManagerAddr != address(0), "POOL_MANAGER_ADDRESS not set");

        AutoCompoundHook hook = AutoCompoundHook(hookAddr);

        // Simule fees acumuladas no hook
        usdc.mint(hookAddr, 100e6); // 100 USDC fees

        // Simule key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(weth)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

        // Criar ModifyLiquidityParams
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: 0,
            tickUpper: 0,
            liquidityDelta: 0,
            salt: bytes32(0)
        });

        // Simule delta (100 USDC fees em token0) e feesAccrued
        BalanceDelta delta = toBalanceDelta(0, 0); // Delta zero
        BalanceDelta feesAccrued = toBalanceDelta(int128(uint128(100e6)), int128(0)); // Fees: 100 USDC em token0

        // Prank PoolManager
        vm.prank(poolManagerAddr);
        hook.afterRemoveLiquidity(
            address(this),
            key,
            params,
            delta,
            feesAccrued,
            ""
        );

        // Verifique pagamento 10% em USDC pra FEE_RECIPIENT
        address feeRecipient = hook.FEE_RECIPIENT();
        uint256 balance = usdc.balanceOf(feeRecipient);
        console.log("Pagamento 10% em USDC pra FEE_RECIPIENT:", balance);

        vm.stopBroadcast();
    }
}
