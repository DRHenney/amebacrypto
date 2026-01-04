// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployAutoCompoundHook is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying AutoCompoundHook...");
        console2.log("PoolManager:", poolManager);

        // Minerar um endereço válido para o hook
        // Os hooks do Uniswap v4 precisam ter endereços específicos baseados nos flags
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        address deployerAddress = vm.addr(deployerPrivateKey);
        bytes memory constructorArgs = abi.encode(IPoolManager(address(poolManager)), deployerAddress);

        // Minerar o endereço
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(AutoCompoundHook).creationCode,
            constructorArgs
        );

        console2.log("Hook address found:", hookAddress);
        console2.log("Salt:", vm.toString(salt));

        // Deploy do hook usando CREATE2 com o salt minerado
        // Pass deployer address as owner parameter
        AutoCompoundHook hook = new AutoCompoundHook{salt: salt}(
            IPoolManager(address(poolManager)),
            deployerAddress
        );

        console2.log("AutoCompoundHook deployed at:", address(hook));
        console2.log("Owner:", hook.owner());

        vm.stopBroadcast();

        // Retornar informações importantes
        console2.log("\n=== Deploy Summary ===");
        console2.log("Hook Address:", address(hook));
        console2.log("PoolManager:", poolManager);
        console2.log("Owner:", hook.owner());
        console2.log("======================");
    }
}

