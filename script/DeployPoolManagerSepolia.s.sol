// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @notice Script to deploy Uniswap v4 PoolManager to Sepolia
/// @dev Execute this script before deploying the hook
contract DeployPoolManagerSepolia is Script {
    function run() external returns (IPoolManager poolManager) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying PoolManager to Sepolia...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // PoolManager requires an address as parameter (owner)
        // We use the deployer as owner
        address owner = vm.addr(deployerPrivateKey);
        
        // Deploy do PoolManager
        poolManager = new PoolManager(owner);
        
        console2.log("");
        console2.log("=== Deploy Summary ===");
        console2.log("PoolManager deployed at:", address(poolManager));
        console2.log("Owner:", owner);
        console2.log("Chain ID:", block.chainid);
        console2.log("======================");
        console2.log("");
        console2.log("IMPORTANT: Copy the address above and add to .env file:");
        console2.log("POOL_MANAGER=", address(poolManager));

        vm.stopBroadcast();
    }
}

