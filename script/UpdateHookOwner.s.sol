// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script to update hook owner
/// @dev After CREATE2 deploy, owner is CREATE2_DEPLOYER, we need to change it
contract UpdateHookOwner is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address newOwner = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        address currentOwner = hook.owner();
        
        console2.log("=== Update Hook Owner ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Current Owner:", currentOwner);
        console2.log("New Owner:", newOwner);
        
        if (currentOwner == newOwner) {
            console2.log("You are already the owner!");
            vm.stopBroadcast();
            return;
        }
        
        // Try to update owner
        // This will only work if current owner is deployer or if we can call from CREATE2_DEPLOYER
        // Since CREATE2_DEPLOYER is not controlled by us, we need another approach
        console2.log("\nAttempting to update owner...");
        
        // Note: This will fail if current owner is CREATE2_DEPLOYER and we can't control it
        try hook.setOwner(newOwner) {
            console2.log("Owner updated successfully!");
            console2.log("New owner:", hook.owner());
        } catch Error(string memory reason) {
            console2.log("Error updating owner:", reason);
            console2.log("\nThe hook owner is currently the CREATE2_DEPLOYER.");
            console2.log("You cannot change it without access to that account.");
            console2.log("\nOptions:");
            console2.log("1. The hook can still work, but you won't be able to configure it");
            console2.log("2. Redeploy with a different approach (not using CREATE2)");
            console2.log("3. Accept CREATE2_DEPLOYER as owner (not recommended)");
        }
        
        vm.stopBroadcast();
    }
}



