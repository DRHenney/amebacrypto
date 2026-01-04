// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script";

/// @notice Script to transfer ETH from one address to another
/// @dev Set SENDER_PRIVATE_KEY in .env for the address that will send ETH
/// @dev Set RECIPIENT_ADDRESS in .env for the address that will receive ETH
/// @dev Set TRANSFER_AMOUNT in .env for the amount to transfer (in wei, e.g., 100000000000000000 for 0.1 ETH)
contract TransferETH is Script {
    function run() external {
        // Get sender private key from env (the other address that has ETH)
        uint256 senderPrivateKey = vm.envUint("SENDER_PRIVATE_KEY");
        address sender = vm.addr(senderPrivateKey);
        
        // Get recipient address from env (or use current deployer address)
        address recipient;
        if (vm.envOr("RECIPIENT_ADDRESS", address(0)) != address(0)) {
            recipient = vm.envAddress("RECIPIENT_ADDRESS");
        } else {
            // Use current deployer as recipient
            uint256 currentPrivateKey = vm.envUint("PRIVATE_KEY");
            recipient = vm.addr(currentPrivateKey);
        }
        
        // Get transfer amount from env (default: 0.1 ETH)
        uint256 amount = vm.envOr("TRANSFER_AMOUNT", uint256(0.1 ether));
        
        uint256 senderBalance = sender.balance;
        
        console2.log("=== Transfer ETH ===");
        console2.log("Sender address:", sender);
        console2.log("Recipient address:", recipient);
        console2.log("Sender balance (wei):", senderBalance);
        console2.log("Sender balance (ETH):", senderBalance / 1e18);
        console2.log("Amount to transfer (wei):", amount);
        console2.log("Amount to transfer (ETH):", amount / 1e18);
        
        // Check if sender has enough balance
        if (senderBalance < amount) {
            console2.log("[ERROR] Insufficient balance!");
            console2.log("Sender balance (ETH):", senderBalance / 1e18);
            console2.log("Amount needed (ETH):", amount / 1e18);
            revert("Insufficient balance");
        }
        
        // Check recipient balance before
        uint256 recipientBalanceBefore = recipient.balance;
        console2.log("Recipient balance before (ETH):", recipientBalanceBefore / 1e18);
        
        vm.startBroadcast(senderPrivateKey);
        
        // Transfer ETH
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        vm.stopBroadcast();
        
        // Check balances after
        uint256 senderBalanceAfter = sender.balance;
        uint256 recipientBalanceAfter = recipient.balance;
        
        console2.log("");
        console2.log("=== Transfer Complete ===");
        console2.log("Sender balance after (ETH):", senderBalanceAfter / 1e18);
        console2.log("Recipient balance after (ETH):", recipientBalanceAfter / 1e18);
        console2.log("ETH transferred:", (recipientBalanceAfter - recipientBalanceBefore) / 1e18, "ETH");
        console2.log("[SUCCESS] Transfer completed successfully!");
    }
}

