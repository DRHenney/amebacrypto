// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Interface for WETH contract
interface IWETH {
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Script to unwrap WETH to ETH
contract UnwrapWETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wethAddress = vm.envAddress("TOKEN1_ADDRESS"); // WETH address from .env
        
        address deployer = vm.addr(deployerPrivateKey);
        uint256 ethBalance = deployer.balance;
        IWETH weth = IWETH(wethAddress);
        uint256 wethBalance = weth.balanceOf(deployer);
        
        console2.log("=== Unwrapping WETH to ETH ===");
        console2.log("Your address:", deployer);
        console2.log("Current ETH balance (wei):", ethBalance);
        console2.log("Current ETH balance (ETH):", ethBalance / 1e18);
        console2.log("Current WETH balance (wei):", wethBalance);
        console2.log("Current WETH balance (WETH):", wethBalance / 1e18);
        console2.log("WETH address:", wethAddress);
        
        // Unwrap all available WETH
        uint256 amountToUnwrap = wethBalance;
        
        // Check if we have any WETH to unwrap
        if (wethBalance == 0) {
            console2.log("[ERROR] No WETH balance to unwrap!");
            console2.log("WETH Balance (wei):", wethBalance);
            console2.log("WETH Balance (WETH):", wethBalance / 1e18);
            revert("No WETH balance");
        }
        
        console2.log("Amount to unwrap (wei):", amountToUnwrap);
        console2.log("Amount to unwrap (WETH):", amountToUnwrap / 1e18);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check ETH balance before
        uint256 ethBalanceBefore = deployer.balance;
        console2.log("ETH balance before (wei):", ethBalanceBefore);
        console2.log("ETH balance before (ETH):", ethBalanceBefore / 1e18);
        
        // Unwrap WETH to ETH by calling withdraw()
        weth.withdraw(amountToUnwrap);
        
        // Check ETH balance after
        uint256 ethBalanceAfter = deployer.balance;
        console2.log("ETH balance after (wei):", ethBalanceAfter);
        console2.log("ETH balance after (ETH):", ethBalanceAfter / 1e18);
        uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;
        console2.log("ETH received (wei):", ethReceived);
        console2.log("ETH received (ETH):", ethReceived / 1e18);
        
        // Check WETH balance after
        uint256 wethBalanceAfter = weth.balanceOf(deployer);
        console2.log("WETH balance after (wei):", wethBalanceAfter);
        console2.log("WETH balance after (WETH):", wethBalanceAfter / 1e18);
        
        console2.log("[SUCCESS] Successfully unwrapped WETH to ETH!");
        console2.log("New ETH balance (ETH):", ethBalanceAfter / 1e18);
        console2.log("Remaining WETH balance (WETH):", wethBalanceAfter / 1e18);
        
        vm.stopBroadcast();
    }
}

