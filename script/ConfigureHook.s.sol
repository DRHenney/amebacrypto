// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @notice Script to configure the hook after deployment
/// @dev Execute after deploying the hook
contract ConfigureHook is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        // Token addresses (configure according to your pool)
        address token0Address = vm.envAddress("TOKEN0_ADDRESS"); // Ex: USDC
        address token1Address = vm.envAddress("TOKEN1_ADDRESS"); // Ex: WETH
        
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
        
        console2.log("=== Configuring Hook ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Token0:", Currency.unwrap(key.currency0));
        console2.log("Token1:", Currency.unwrap(key.currency1));
        
        // Check owner first
        address currentOwner = hook.owner();
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Current Owner:", currentOwner);
        console2.log("Your Address:", deployerAddress);
        
        if (currentOwner != deployerAddress) {
            console2.log("\nWARNING: You are not the owner!");
            console2.log("Current owner is:", currentOwner);
            console2.log("You need to be owner to configure the hook.");
            console2.log("Please update owner first using setOwner()");
            revert("Not the owner of the hook");
        }
        
        // 1. Enable pool
        console2.log("\n1. Enabling pool...");
        hook.setPoolConfig(key, true);
        console2.log("Pool enabled");
        
        // 2. Configure token prices (USD)
        // IMPORTANT: Adjust according to current prices!
        // Prices in 18 decimals format: price * 1e18
        // Example: ETH = $3000 -> 3000e18
        uint256 token0PriceUSD = vm.envUint("TOKEN0_PRICE_USD"); // Ex: 1e18 for USDC = $1
        uint256 token1PriceUSD = vm.envUint("TOKEN1_PRICE_USD"); // Ex: 3000e18 for ETH = $3000
        
        console2.log("\n2. Configuring token prices...");
        console2.log("Token0 Price USD:", token0PriceUSD);
        console2.log("Token1 Price USD:", token1PriceUSD);
        hook.setTokenPricesUSD(key, token0PriceUSD, token1PriceUSD);
        console2.log("Prices configured");
        
        // 3. Configure tick range
        // Full range: -887280 to 887280 (aligned with tickSpacing = 60)
        // Ticks must be multiples of tickSpacing
        int24 tickSpacing = 60;
        int24 tickLower = int24(vm.envInt("TICK_LOWER")); // Default: -887280
        int24 tickUpper = int24(vm.envInt("TICK_UPPER")); // Default: 887280
        
        // Align ticks to tickSpacing
        if (tickLower % tickSpacing != 0) {
            tickLower = (tickLower / tickSpacing) * tickSpacing;
            if (tickLower > 0 && tickLower % tickSpacing != 0) {
                tickLower -= tickSpacing;
            }
        }
        if (tickUpper % tickSpacing != 0) {
            tickUpper = (tickUpper / tickSpacing) * tickSpacing;
            if (tickUpper < 0 && tickUpper % tickSpacing != 0) {
                tickUpper += tickSpacing;
            }
        }
        
        console2.log("\n3. Configuring tick range...");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        hook.setPoolTickRange(key, tickLower, tickUpper);
        console2.log("Tick range configured");
        
        // 4. Verify configuration
        console2.log("\n=== Verifying Configuration ===");
        (
            AutoCompoundHook.PoolConfig memory config,
            uint256 fees0,
            uint256 fees1,
            int24 storedTickLower,
            int24 storedTickUpper
        ) = hook.getPoolInfo(key);
        
        console2.log("Pool Enabled:", config.enabled);
        console2.log("Fees0:", fees0);
        console2.log("Fees1:", fees1);
        console2.log("Tick Lower:", storedTickLower);
        console2.log("Tick Upper:", storedTickUpper);
        
        // 5. Check if compound can be executed
        (
            bool canCompound,
            string memory reason,
            uint256 timeUntilNextCompound,
            uint256 feesValueUSD,
            uint256 gasCostUSD
        ) = hook.canExecuteCompound(key);
        
        console2.log("\n=== Compound Status ===");
        console2.log("Can execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time until next compound:", timeUntilNextCompound, "seconds");
        console2.log("Fees value (USD):", feesValueUSD);
        console2.log("Gas cost (USD):", gasCostUSD);
        
        vm.stopBroadcast();
        
        console2.log("\nConfiguration completed!");
    }
}

