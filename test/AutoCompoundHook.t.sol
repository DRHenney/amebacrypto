// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "lib/v4-periphery/src/utils/BaseHook.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @notice Test version of AutoCompoundHook that skips address validation
contract AutoCompoundHookTestImpl is AutoCompoundHook {
    constructor(IPoolManager _poolManager) AutoCompoundHook(_poolManager) {}
    
    /// @notice Override to skip validation in tests
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation in tests
    }
}

contract AutoCompoundHookTest is Test {
    using PoolIdLibrary for PoolKey;

    AutoCompoundHook public hook;
    IPoolManager public poolManager;
    
    PoolKey public poolKey;
    PoolId public poolId;

    address public owner = address(0x1);
    address public user = address(0x2);
    address public mockPoolManager = address(0x100);

    function setUp() public {
        // Criar mock do PoolManager (em testes reais, você usaria um mock completo)
        // Por enquanto, apenas criamos um endereço mock
        vm.etch(mockPoolManager, new bytes(1));
        
        // Fazer deploy usando a versão de teste que não valida o endereço
        vm.prank(owner);
        hook = new AutoCompoundHookTestImpl(IPoolManager(mockPoolManager));
        
        // Criar poolKey de exemplo
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
    }

    function test_Constructor() public view {
        assertEq(hook.owner(), owner);
        assertEq(address(hook.poolManager()), mockPoolManager);
    }

    function test_SetPoolConfig() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, true);
        
        (bool enabled) = hook.poolConfigs(poolId);
        
        assertTrue(enabled);
    }

    function test_SetPoolTickRange() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolTickRange(key, -887272, 887272);
        
        // Note: não há getter público, mas podemos verificar via getPoolInfo
        PoolKey memory key2 = poolKey;
        (
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper
        ) = hook.getPoolInfo(key2);
        
        assertEq(tickLower, -887272);
        assertEq(tickUpper, 887272);
    }

    function test_AccumulateFees() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, true);
        
        PoolKey memory key2 = poolKey;
        hook.accumulateFees(key2, 5e17, 5e17);
        
        assertEq(hook.accumulatedFees0(poolId), 5e17);
        assertEq(hook.accumulatedFees1(poolId), 5e17);
    }

    function test_AccumulateFees_Disabled() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, false);
        
        PoolKey memory key2 = poolKey;
        hook.accumulateFees(key2, 5e17, 5e17);
        
        // Taxas não devem ser acumuladas se desabilitado
        assertEq(hook.accumulatedFees0(poolId), 0);
        assertEq(hook.accumulatedFees1(poolId), 0);
    }

    function test_TryCompound_BelowThreshold() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, true);
        
        PoolKey memory key2 = poolKey;
        hook.accumulateFees(key2, 5e17, 5e17);
        
        PoolKey memory key3 = poolKey;
        hook.tryCompound(key3);
        
        // Taxas não devem ser resetadas pois condições não foram atendidas
        // (preços não configurados ou fees < 20x gas cost)
        assertEq(hook.accumulatedFees0(poolId), 5e17);
        assertEq(hook.accumulatedFees1(poolId), 5e17);
    }

    function test_SetOwner() public {
        address newOwner = address(0x999);
        
        vm.prank(owner);
        hook.setOwner(newOwner);
        
        assertEq(hook.owner(), newOwner);
    }

    function test_GetPoolInfo() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, true);
        
        PoolKey memory key2 = poolKey;
        vm.prank(owner);
        hook.setPoolTickRange(key2, -100, 100);
        
        PoolKey memory key3 = poolKey;
        hook.accumulateFees(key3, 5e17, 5e17);
        
        PoolKey memory key4 = poolKey;
        (
            AutoCompoundHook.PoolConfig memory config,
            uint256 fees0,
            uint256 fees1,
            int24 tickLower,
            int24 tickUpper
        ) = hook.getPoolInfo(key4);
        
        assertTrue(config.enabled);
        assertEq(fees0, 5e17);
        assertEq(fees1, 5e17);
        assertEq(tickLower, -100);
        assertEq(tickUpper, 100);
    }

    function test_Revert_NotOwner_SetPoolConfig() public {
        PoolKey memory key = poolKey;
        vm.prank(user);
        vm.expectRevert("Not owner");
        hook.setPoolConfig(key, true);
    }

    function test_Revert_NotOwner_SetPoolTickRange() public {
        PoolKey memory key = poolKey;
        vm.prank(user);
        vm.expectRevert("Not owner");
        hook.setPoolTickRange(key, -100, 100);
    }

    function test_Revert_NotOwner_SetOwner() public {
        vm.prank(user);
        vm.expectRevert("Not owner");
        hook.setOwner(address(0x999));
    }

    function test_Revert_InvalidOwner() public {
        vm.prank(owner);
        vm.expectRevert("Invalid owner");
        hook.setOwner(address(0));
    }

    function test_Revert_InvalidTickRange() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        vm.expectRevert("Invalid tick range");
        hook.setPoolTickRange(key, 100, -100); // tickLower > tickUpper
    }

    function test_EmergencyWithdraw() public {
        PoolKey memory key = poolKey;
        vm.prank(owner);
        hook.setPoolConfig(key, true);
        
        PoolKey memory key2 = poolKey;
        hook.accumulateFees(key2, 1e18, 1e18);
        
        address recipient = address(0x999);
        
        PoolKey memory key3 = poolKey;
        vm.prank(owner);
        hook.emergencyWithdraw(key3, recipient);
        
        // Taxas devem ser resetadas
        assertEq(hook.accumulatedFees0(poolId), 0);
        assertEq(hook.accumulatedFees1(poolId), 0);
    }
}

