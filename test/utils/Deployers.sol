// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";
import {AddressConstants} from "hookmate/constants/AddressConstants.sol";

import {Permit2Deployer} from "hookmate/artifacts/Permit2.sol";
import {V4PoolManagerDeployer} from "hookmate/artifacts/V4PoolManager.sol";
import {V4PositionManagerDeployer} from "hookmate/artifacts/V4PositionManager.sol";
import {V4RouterDeployer} from "hookmate/artifacts/V4Router.sol";

/// @notice Helper contract for deploying Uniswap v4 artifacts in scripts
contract Deployers is Script {
    IPermit2 public permit2;
    IPoolManager public poolManager;
    IPositionManager public positionManager;
    IUniswapV4Router04 public swapRouter;

    /// @notice Deploys all Uniswap v4 artifacts
    /// @dev Uses CREATE2 to deploy at deterministic addresses
    function deployArtifacts() internal {
        uint256 chainId = block.chainid;
        
        // Get addresses from AddressConstants if deployed, otherwise deploy
        address permit2Address = AddressConstants.getPermit2Address();
        if (permit2Address.code.length == 0) {
            permit2 = IPermit2(Permit2Deployer.deploy());
        } else {
            permit2 = IPermit2(permit2Address);
        }

        // Deploy PoolManager (needs an owner, using deployer address)
        address deployer = getDeployer();
        address poolManagerAddress = AddressConstants.getPoolManagerAddress(chainId);
        if (poolManagerAddress.code.length == 0) {
            poolManager = IPoolManager(V4PoolManagerDeployer.deploy(deployer));
        } else {
            poolManager = IPoolManager(poolManagerAddress);
        }

        // Deploy PositionManager (needs poolManager, permit2, unsubscribeGasLimit, positionDescriptor, weth)
        address positionManagerAddress = AddressConstants.getPositionManagerAddress(chainId);
        if (positionManagerAddress.code.length == 0) {
            // Using default values for PositionManager deployment
            uint256 unsubscribeGasLimit = 50000;
            address positionDescriptor = address(0); // Can be set later if needed
            address weth = address(0); // Can be set later if needed
            positionManager = IPositionManager(
                V4PositionManagerDeployer.deploy(
                    address(poolManager),
                    address(permit2),
                    unsubscribeGasLimit,
                    positionDescriptor,
                    weth
                )
            );
        } else {
            positionManager = IPositionManager(positionManagerAddress);
        }

        // Deploy Router (needs poolManager and permit2)
        address routerAddress = AddressConstants.getV4SwapRouterAddress(chainId);
        if (routerAddress.code.length == 0) {
            swapRouter = IUniswapV4Router04(
                payable(V4RouterDeployer.deploy(address(poolManager), address(permit2)))
            );
        } else {
            swapRouter = IUniswapV4Router04(payable(routerAddress));
        }
    }

    /// @notice Gets the deployer address (internal helper)
    function _getDeployer() internal returns (address) {
        address[] memory wallets = vm.getWallets();
        if (wallets.length > 0) {
            return wallets[0];
        } else {
            return msg.sender;
        }
    }

    /// @notice Gets the deployer address (can be overridden)
    function getDeployer() internal virtual returns (address) {
        return _getDeployer();
    }

    /// @notice Internal function for etching (used in BaseScript)
    function _etch(address target, bytes memory bytecode) internal virtual {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("Unsupported etch on this network");
        }
    }
}

