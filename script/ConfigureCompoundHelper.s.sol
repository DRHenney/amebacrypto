// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {CompoundHelper} from "../src/helpers/CompoundHelper.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script to configure CompoundHelper in the hook
/// @dev This can be done before adding liquidity
contract ConfigureCompoundHelper is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
        // Create PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Configuring CompoundHelper ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // Check if CompoundHelper is already configured
        address existingHelper = hook.compoundHelper(poolId);
        
        if (existingHelper != address(0)) {
            console2.log("CompoundHelper already configured!");
            console2.log("CompoundHelper Address:", existingHelper);
            console2.log("");
            console2.log("CompoundHelper is ready to use fees reais!");
            vm.stopBroadcast();
            return;
        }
        
        // Check owner
        address currentOwner = hook.owner();
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Current Owner:", currentOwner);
        console2.log("Your Address:", deployerAddress);
        
        if (currentOwner != deployerAddress) {
            console2.log("ERROR: You are not the owner of the hook!");
            console2.log("Only the owner can configure CompoundHelper.");
            vm.stopBroadcast();
            return;
        }
        console2.log("");
        
        // Deploy CompoundHelper if not exists
        console2.log("=== Deploying CompoundHelper ===");
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        console2.log("CompoundHelper deployed at:", address(helper));
        console2.log("");
        
        // Configure CompoundHelper in hook
        console2.log("=== Configuring CompoundHelper in Hook ===");
        hook.setCompoundHelper(poolKey, address(helper));
        console2.log("CompoundHelper configured successfully!");
        console2.log("");
        
        // Verify configuration
        address configuredHelper = hook.compoundHelper(poolId);
        if (configuredHelper == address(helper)) {
            console2.log("Verification: CompoundHelper is correctly configured!");
            console2.log("Address:", configuredHelper);
        } else {
            console2.log("WARNING: Configuration verification failed!");
        }
        console2.log("");
        console2.log("=== Summary ===");
        console2.log("CompoundHelper Address:", address(helper));
        console2.log("Hook Address:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        console2.log("CompoundHelper is now configured!");
        console2.log("The hook will now use REAL fees when executing compound.");
        console2.log("(You can add liquidity and accumulate fees now)");
        
        vm.stopBroadcast();
    }
}

