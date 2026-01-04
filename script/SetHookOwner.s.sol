// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script to set the hook owner to your wallet
/// @dev Execute this after deploying the hook
contract SetHookOwner is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address newOwner = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Setting Hook Owner ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Current Owner:", hook.owner());
        console2.log("New Owner:", newOwner);
        
        // Check if already owner
        if (hook.owner() == newOwner) {
            console2.log("You are already the owner!");
        } else {
            // Need to call setOwner from current owner
            // If current owner is CREATE2_DEPLOYER, we need to use that account
            address currentOwner = hook.owner();
            console2.log("");
            console2.log("WARNING: Current owner is:", currentOwner);
            console2.log("To change owner, you need to call setOwner() from the current owner account.");
            console2.log("This may require using a different private key if owner is CREATE2_DEPLOYER.");
        }
        
        vm.stopBroadcast();
    }
}



