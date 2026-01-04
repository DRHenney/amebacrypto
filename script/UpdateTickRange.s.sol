// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @notice Script to update tick range to aligned values
contract UpdateTickRange is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        // Aligned ticks for tickSpacing = 60
        // MIN_TICK = -887272, MAX_TICK = 887272
        // Find aligned ticks within valid range
        int24 tickLower = -887220; // First multiple of 60 >= MIN_TICK
        int24 tickUpper = 887220;  // First multiple of 60 <= MAX_TICK
        
        console2.log("=== Updating Tick Range ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("TickSpacing: 60");
        console2.log("TickLower aligned:", tickLower % 60 == 0);
        console2.log("TickUpper aligned:", tickUpper % 60 == 0);
        
        hook.setPoolTickRange(key, tickLower, tickUpper);
        
        console2.log("Tick range updated successfully!");
        
        vm.stopBroadcast();
    }
}

