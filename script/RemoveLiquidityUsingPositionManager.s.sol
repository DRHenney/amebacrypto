// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PositionInfo} from "@uniswap/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to remove liquidity using PositionManager by burning NFT positions
contract RemoveLiquidityUsingPositionManager is Script {
    
    // Known hook addresses with liquidity
    address[] hookAddresses = [
        0x7BC9dDcbE9F25A249Ac4c07a6d86616E78E45540, // Oldest
        0x01308892b21f3E6fB6fF8e13a29D775e991D5540, // Medium
        0xEaF32b3657427a3796928035d6B2DBb28C355540  // Newer
    ];
    
    // PositionManager address on Sepolia
    address constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        IPositionManager positionManager = IPositionManager(POSITION_MANAGER);
        IERC721 nft = IERC721(POSITION_MANAGER);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("=== Removendo Liquidez usando PositionManager ===");
        console2.log("PositionManager:", POSITION_MANAGER);
        console2.log("Deployer:", deployer);
        
        // Get number of NFTs owned by deployer
        uint256 balance = nft.balanceOf(deployer);
        console2.log("\nNFT Balance (positions owned):", balance);
        
        if (balance == 0) {
            console2.log("\nAVISO: Voce nao possui nenhuma posicao NFT no PositionManager!");
            console2.log("A liquidez pode ter sido adicionada diretamente (sem PositionManager)");
            vm.stopBroadcast();
            return;
        }
        
        // Get nextTokenId to know the max tokenId to check
        uint256 nextTokenId = positionManager.nextTokenId();
        console2.log("Next Token ID:", nextTokenId);
        console2.log("Verificando tokenIds de 1 ate", nextTokenId - 1);
        
        // Find tokens owned by deployer
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 found = 0;
        
        for (uint256 i = 1; i < nextTokenId && found < balance; i++) {
            try nft.ownerOf(i) returns (address owner) {
                if (owner == deployer) {
                    tokenIds[found] = i;
                    found++;
                }
            } catch {
                // Token doesn't exist, continue
            }
        }
        
        console2.log("\n=== Tokens Encontrados ===");
        console2.log("Total de tokens encontrados:", found);
        
        if (found == 0) {
            console2.log("Nenhum token encontrado (pode ser problema de enumeracao)");
            vm.stopBroadcast();
            return;
        }
        
        // Get balances before
        uint256 deployerBalance0Before = IERC20Minimal(token0Address).balanceOf(deployer);
        uint256 deployerBalance1Before = IERC20Minimal(token1Address).balanceOf(deployer);
        
        console2.log("\n=== Saldos Antes ===");
        console2.log("USDC Balance:", deployerBalance0Before);
        console2.log("WETH Balance:", deployerBalance1Before);
        console2.log("WETH Balance (WETH):", deployerBalance1Before / 1e18);
        
        // Check each token and burn if it's from an old pool
        uint256 burned = 0;
        
        for (uint256 i = 0; i < found; i++) {
            uint256 tokenId = tokenIds[i];
            
            try positionManager.getPoolAndPositionInfo(tokenId) returns (
                PoolKey memory poolKey,
                PositionInfo positionInfo
            ) {
                address hookAddress = address(poolKey.hooks);
                
                console2.log("\n--- Token ID:", tokenId);
                console2.log("Hook Address:", hookAddress);
                
                // Check if this hook is one of the old hooks with liquidity
                bool isOldPool = false;
                for (uint256 j = 0; j < hookAddresses.length; j++) {
                    if (hookAddress == hookAddresses[j]) {
                        isOldPool = true;
                        break;
                    }
                }
                
                if (!isOldPool) {
                    console2.log("Pool nao e uma das pools antigas conhecidas, pulando...");
                    continue;
                }
                
                // Get liquidity
                uint128 liquidity = positionManager.getPositionLiquidity(tokenId);
                console2.log("Liquidity:", liquidity);
                
                if (liquidity == 0) {
                    console2.log("Posicao sem liquidez, pulando...");
                    continue;
                }
                
                console2.log("Queimando posicao e removendo liquidez...");
                
                // Burn the position using modifyLiquidities
                // BURN_POSITION action requires: tokenId, amount0Min, amount1Min, hookData
                // We need to encode: actions bytes and params bytes[]
                bytes memory actions = new bytes(3);
                bytes[] memory params = new bytes[](3);
                
                // Action 0: BURN_POSITION
                actions[0] = bytes1(uint8(Actions.BURN_POSITION));
                params[0] = abi.encode(tokenId, uint128(0), uint128(0), bytes(""));
                
                // Action 1: CLOSE_CURRENCY for currency0
                actions[1] = bytes1(uint8(Actions.CLOSE_CURRENCY));
                params[1] = abi.encode(poolKey.currency0);
                
                // Action 2: CLOSE_CURRENCY for currency1
                actions[2] = bytes1(uint8(Actions.CLOSE_CURRENCY));
                params[2] = abi.encode(poolKey.currency1);
                
                bytes memory unlockData = abi.encode(actions, params);
                
                // Execute the burn
                positionManager.modifyLiquidities(unlockData, block.timestamp + 3600);
                
                console2.log("Posicao queimada com sucesso!");
                burned++;
                
            } catch Error(string memory reason) {
                console2.log("Erro ao processar token:", reason);
            } catch {
                console2.log("Erro desconhecido ao processar token");
            }
        }
        
        console2.log("\n=== Resultado ===");
        console2.log("Posicoes queimadas:", burned);
        
        // Get balances after
        uint256 deployerBalance0After = IERC20Minimal(token0Address).balanceOf(deployer);
        uint256 deployerBalance1After = IERC20Minimal(token1Address).balanceOf(deployer);
        
        console2.log("\n=== Saldos Depois ===");
        console2.log("USDC Balance:", deployerBalance0After);
        console2.log("WETH Balance:", deployerBalance1After);
        console2.log("WETH Balance (WETH):", deployerBalance1After / 1e18);
        
        uint256 wethReceived = deployerBalance1After > deployerBalance1Before ? 
            deployerBalance1After - deployerBalance1Before : 0;
        
        console2.log("\n=== WETH Recebido ===");
        console2.log("WETH Recebido (wei):", wethReceived);
        console2.log("WETH Recebido (WETH):", wethReceived / 1e18);
        
        vm.stopBroadcast();
    }
}

