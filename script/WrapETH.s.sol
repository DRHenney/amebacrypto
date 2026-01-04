// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Interface for WETH contract
interface IWETH {
    function deposit() external payable;
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Script to wrap ETH to WETH
contract WrapETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wethAddress = vm.envAddress("TOKEN1_ADDRESS"); // WETH address from .env
        
        address deployer = vm.addr(deployerPrivateKey);
        uint256 ethBalance = deployer.balance;
        
        console2.log("=== Wrapping ETH to WETH ===");
        console2.log("Your address:", deployer);
        console2.log("ETH balance:", ethBalance);
        console2.log("WETH address:", wethAddress);
        
        // Get amount to wrap from env or use available balance (minus gas reserve)
        uint256 amountToWrap;
        if (vm.envOr("WRAP_AMOUNT", uint256(0)) > 0) {
            amountToWrap = vm.envUint("WRAP_AMOUNT");
        } else if (vm.envOr("WRAP_ALL_ETH", bool(false))) {
            // Wrap 95% of available balance (keep 5% for gas) when WRAP_ALL_ETH is true
            amountToWrap = (ethBalance * 95) / 100;
        } else {
            // Default: wrap 90% of available balance (keep 10% for gas)
            amountToWrap = (ethBalance * 90) / 100;
        }
        
        if (amountToWrap > ethBalance) {
            console2.log("\nError: Insufficient ETH balance!");
            console2.log("ETH Balance:", ethBalance);
            console2.log("Amount to wrap:", amountToWrap);
            console2.log("\nYou need at least", amountToWrap / 1e18, "ETH");
            revert("Insufficient ETH balance");
        }
        
        console2.log("\nAmount to wrap:", amountToWrap, "wei");
        console2.log("Amount to wrap:", amountToWrap / 1e18, "ETH");
        
        IWETH weth = IWETH(wethAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check WETH balance before
        uint256 wethBalanceBefore = weth.balanceOf(deployer);
        console2.log("\nWETH balance before:", wethBalanceBefore);
        
        // Wrap ETH to WETH by calling deposit() with ETH value
        weth.deposit{value: amountToWrap}();
        
        // Check WETH balance after
        uint256 wethBalanceAfter = weth.balanceOf(deployer);
        console2.log("WETH balance after:", wethBalanceAfter);
        console2.log("WETH received:", wethBalanceAfter - wethBalanceBefore);
        
        console2.log("\nSuccessfully wrapped ETH to WETH!");
        console2.log("New WETH balance:", wethBalanceAfter);
        
        vm.stopBroadcast();
    }
}

