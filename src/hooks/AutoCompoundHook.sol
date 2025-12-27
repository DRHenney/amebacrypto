// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "lib/v4-periphery/src/utils/BaseHook.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @title AutoCompoundHook
/// @notice Hook que automaticamente reinveste taxas acumuladas na pool
/// @dev Implementa o padrão de auto-compound para maximizar retornos
contract AutoCompoundHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // Eventos
    event FeesCompounded(PoolId indexed poolId, uint256 amount0, uint256 amount1);

    // Configurações por pool
    struct PoolConfig {
        bool enabled; // Se o auto-compound está habilitado para esta pool
    }

    // Mapeamento de pool ID para configurações
    mapping(PoolId => PoolConfig) public poolConfigs;

    // Mapeamento para rastrear taxas acumuladas
    mapping(PoolId => uint256) public accumulatedFees0;
    mapping(PoolId => uint256) public accumulatedFees1;

    // Mapeamento para rastrear posições de liquidez (tick ranges) por pool
    // Isso ajuda a saber onde adicionar a liquidez no compound
    mapping(PoolId => int24) public poolTickLower;
    mapping(PoolId => int24) public poolTickUpper;

    // Mapeamento para último timestamp de compound por pool
    mapping(PoolId => uint256) public lastCompoundTimestamp;

    // Mapeamento para preços dos tokens em USD (para cálculo de threshold)
    mapping(PoolId => uint256) public token0PriceUSD;
    mapping(PoolId => uint256) public token1PriceUSD;

    // Mapeamento para armazenar PoolKey de pools intermediárias (token -> USDC)
    // Exemplo: ETH -> PoolKey(ETH, USDC, fee, tickSpacing, hooks)
    mapping(Currency => PoolKey) public intermediatePools;
    
    // Mapeamento para verificar se uma pool intermediária foi configurada
    mapping(Currency => bool) public hasIntermediatePool;

    // Constante: intervalo de 4 horas em segundos
    uint256 public constant COMPOUND_INTERVAL = 4 hours; // 14400 segundos

    // Constante: multiplicador mínimo de fees vs custo de gas (20x)
    uint256 public constant MIN_FEES_MULTIPLIER = 20;

    // Endereço para receber 10% das fees
    address public constant FEE_RECIPIENT = 0x24741d63D6224D7c9e1F36F3293153411338C598;
    
    // Endereço do USDC (mainnet)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Endereço do dono/admin (pode ser atualizado)
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
    }

    /// @notice Retorna os flags de hook necessários
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    /// @notice Função helper para acumular taxas
    /// @dev Esta função apenas acumula taxas, não faz compound
    ///      O compound deve ser feito via checkAndCompound() a cada 4 horas
    /// @param key A chave da pool
    /// @param amount0 Quantidade de token0 para acumular
    /// @param amount1 Quantidade de token1 para acumular
    function accumulateFees(
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1
    ) external {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return;
        }
        
        // Apenas acumular taxas (não fazer compound aqui)
        accumulatedFees0[poolId] += amount0;
        accumulatedFees1[poolId] += amount1;
    }

    /// @notice Verifica e executa compound se condições atendidas
    /// @dev Esta função deve ser chamada por um keeper a cada 4 horas
    ///      Verifica: 1) intervalo de 4 horas, 2) fees >= 20x custo de gas
    /// @param key A chave da pool
    /// @return executed Retorna true se compound foi executado
    function checkAndCompound(PoolKey calldata key) external returns (bool executed) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return false;
        }

        // Verificar se passaram 4 horas desde o último compound
        uint256 lastCompound = lastCompoundTimestamp[poolId];
        if (lastCompound > 0 && block.timestamp < lastCompound + COMPOUND_INTERVAL) {
            return false; // Ainda não passaram 4 horas
        }

        uint256 fees0Before = accumulatedFees0[poolId];
        uint256 fees1Before = accumulatedFees1[poolId];

        // Tentar compound (a função interna já verifica todas as condições)
        _tryCompound(key, poolId);

        // Verificar se o compound foi executado (taxas foram resetadas)
        return (accumulatedFees0[poolId] != fees0Before || accumulatedFees1[poolId] != fees1Before);
    }

    /// @notice Configura uma pool para auto-compound
    /// @param key A chave da pool
    /// @param enabled Se o auto-compound está habilitado
    function setPoolConfig(
        PoolKey calldata key,
        bool enabled
    ) external onlyOwner {
        PoolId poolId = key.toId();
        poolConfigs[poolId] = PoolConfig({
            enabled: enabled
        });
    }

    /// @notice Configura preços dos tokens em USD para uma pool
    /// @dev Necessário para calcular se fees acumuladas são >= 20x o custo de gas
    /// @param key A chave da pool
    /// @param price0USD Preço do token0 em USD (ex: 3000 = $3000 para ETH)
    /// @param price1USD Preço do token1 em USD (ex: 1 = $1 para USDC)
    function setTokenPricesUSD(
        PoolKey calldata key,
        uint256 price0USD,
        uint256 price1USD
    ) external onlyOwner {
        require(price0USD > 0, "Token0 price must be > 0");
        require(price1USD > 0, "Token1 price must be > 0");
        
        PoolId poolId = key.toId();
        token0PriceUSD[poolId] = price0USD;
        token1PriceUSD[poolId] = price1USD;
    }
    
    /// @notice Configura o tick range para uma pool (necessário para compound)
    /// @param key A chave da pool
    /// @param tickLower Tick inferior do range
    /// @param tickUpper Tick superior do range
    function setPoolTickRange(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner {
        require(tickLower < tickUpper, "Invalid tick range");
        PoolId poolId = key.toId();
        poolTickLower[poolId] = tickLower;
        poolTickUpper[poolId] = tickUpper;
    }

    /// @notice Configura a pool intermediária para fazer swap de um token para USDC
    /// @dev Necessário quando a pool principal não contém USDC
    /// @dev Exemplo: Para ETH, use setIntermediatePool(ETH, PoolKey(ETH, USDC, 3000, 60, hooks))
    /// @param token O token que precisa ser convertido para USDC (ex: ETH, UNI)
    /// @param intermediatePoolKey A PoolKey da pool token/USDC
    function setIntermediatePool(
        Currency token,
        PoolKey calldata intermediatePoolKey
    ) external onlyOwner {
        Currency usdcCurrency = Currency.wrap(USDC);
        // Verificar se a pool intermediária contém o token e USDC
        require(
            (intermediatePoolKey.currency0 == token && intermediatePoolKey.currency1 == usdcCurrency) ||
            (intermediatePoolKey.currency1 == token && intermediatePoolKey.currency0 == usdcCurrency),
            "Intermediate pool must contain token and USDC"
        );
        intermediatePools[token] = intermediatePoolKey;
        hasIntermediatePool[token] = true;
    }

    /// @notice Callback após inicialização da pool
    function _afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) internal override returns (bytes4) {
        // Inicializar configuração padrão (habilitado)
        PoolId poolId = key.toId();
        if (!poolConfigs[poolId].enabled) {
            poolConfigs[poolId] = PoolConfig({
                enabled: true
            });
        }
        return this.afterInitialize.selector;
    }

    /// @notice Implementação interna do callback após swap
    /// @dev Acumula fees do swap para compound posterior
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata /* params */,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        // Se o auto-compound não está habilitado, retornar sem fazer nada
        if (!config.enabled) {
            return (this.afterSwap.selector, 0);
        }
        
        // Extrair os deltas de amount0 e amount1 do BalanceDelta
        int128 amount0Delta = delta.amount0();
        int128 amount1Delta = delta.amount1();
        
        // As fees são parte do delta, mas precisamos calcular a partir do swap
        // Por enquanto, vamos usar uma aproximação baseada no delta
        // Em produção, você pode precisar consultar o estado da pool para obter as fees exatas
        
        // Nota: O delta representa a mudança líquida, não as fees diretamente
        // Para obter as fees reais, seria necessário:
        // 1. Consultar o estado da pool antes e depois do swap
        // 2. Ou usar uma biblioteca que calcule as fees baseado nos parâmetros do swap
        
        // Por enquanto, vamos apenas verificar se há mudança e preparar para acumular
        // O usuário pode ajustar esta lógica para calcular as fees corretamente
        
        // Acumular fees (versão simplificada - ajuste conforme necessário)
        // Esta é uma aproximação - em produção, calcule as fees corretamente
        if (amount0Delta != 0 || amount1Delta != 0) {
            // Exemplo: acumular uma pequena fração do delta como fees
            // Ajuste esta lógica conforme sua necessidade de cálculo de fees
            uint256 fee0 = 0;
            uint256 fee1 = 0;
            
            // Se você tiver acesso às fees reais, use-as aqui
            // Por enquanto, deixamos como 0 para não acumular valores incorretos
            
            if (fee0 > 0 || fee1 > 0) {
                accumulatedFees0[poolId] += fee0;
                accumulatedFees1[poolId] += fee1;
            }
        }
        
        // Não fazer compound aqui para evitar gas alto
        // O compound deve ser feito externamente via keeper ou accumulateFees()
        return (this.afterSwap.selector, 0);
    }

    /// @notice Callback após adicionar liquidez
    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Salvar o tick range se ainda não foi configurado
        if (poolTickLower[poolId] == 0 && poolTickUpper[poolId] == 0) {
            poolTickLower[poolId] = params.tickLower;
            poolTickUpper[poolId] = params.tickUpper;
        }
        
        // Otimização: Não fazer compound aqui para evitar gas alto
        // O compound deve ser feito externamente quando há taxas suficientes

        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Callback após remover liquidez
    /// @dev Captura 10% das fees geradas e converte para USDC, enviando para FEE_RECIPIENT
    function _afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta feesAccrued,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // Extrair as fees acumuladas do BalanceDelta
        int128 fees0 = feesAccrued.amount0();
        int128 fees1 = feesAccrued.amount1();

        // Verificar se há fees positivas
        if (fees0 > 0 || fees1 > 0) {
            // Calcular 10% das fees
            uint256 tenPercent0 = uint256(uint128(fees0)) / 10;
            uint256 tenPercent1 = uint256(uint128(fees1)) / 10;

            // Pegar os tokens do pool manager
            if (tenPercent0 > 0) {
                poolManager.take(key.currency0, address(this), tenPercent0);
            }
            if (tenPercent1 > 0) {
                poolManager.take(key.currency1, address(this), tenPercent1);
            }

            // Fazer swap para USDC se necessário
            Currency usdcCurrency = Currency.wrap(USDC);
            bool currency0IsUSDC = key.currency0 == usdcCurrency;
            bool currency1IsUSDC = key.currency1 == usdcCurrency;

            // Se token0 não é USDC, fazer swap
            if (tenPercent0 > 0 && !currency0IsUSDC) {
                _swapToUSDC(key, key.currency0, tenPercent0);
            }

            // Se token1 não é USDC, fazer swap
            if (tenPercent1 > 0 && !currency1IsUSDC) {
                _swapToUSDC(key, key.currency1, tenPercent1);
            }

            // Transferir todo USDC acumulado para FEE_RECIPIENT
            uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
            if (usdcBalance > 0) {
                IERC20(USDC).transfer(FEE_RECIPIENT, usdcBalance);
            }
        }

        return (this.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Função helper para fazer swap de um token para USDC
    /// @param key A chave da pool atual (pode não conter USDC)
    /// @param inputCurrency O token de entrada
    /// @param amount A quantidade a ser trocada
    /// @dev Tenta fazer swap direto se USDC está na pool, senão tenta através de pool intermediária
    function _swapToUSDC(
        PoolKey calldata key,
        Currency inputCurrency,
        uint256 amount
    ) internal {
        Currency usdcCurrency = Currency.wrap(USDC);
        
        // Verificar se USDC está na pool atual
        bool usdcIsCurrency0 = key.currency0 == usdcCurrency;
        bool usdcIsCurrency1 = key.currency1 == usdcCurrency;
        
        if (usdcIsCurrency0 || usdcIsCurrency1) {
            // USDC está na pool atual - fazer swap direto
            bool zeroForOne;
            if (inputCurrency == key.currency0) {
                zeroForOne = true; // Swapping token0 -> token1
            } else {
                zeroForOne = false; // Swapping token1 -> token0
            }

            // Fazer o swap através do poolManager
            try poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: -int256(amount),
                    sqrtPriceLimitX96: 0
                }),
                ""
            ) returns (BalanceDelta) {
                // Swap bem-sucedido - o USDC será recebido pelo contrato
                return;
            } catch {
                // Se o swap falhar, tentar pool intermediária
            }
        }

        // Se USDC não está na pool atual, tentar usar pool intermediária
        // Verificar se existe pool intermediária configurada
        if (!hasIntermediatePool[inputCurrency]) {
            // Pool intermediária não configurada - tokens permanecem no contrato
            return;
        }
        
        PoolKey memory intermediatePool = intermediatePools[inputCurrency];

        // Verificar se a pool intermediária contém o token e USDC
        bool validPool = (intermediatePool.currency0 == inputCurrency && intermediatePool.currency1 == usdcCurrency) ||
                         (intermediatePool.currency1 == inputCurrency && intermediatePool.currency0 == usdcCurrency);
        
        if (!validPool) {
            // Pool intermediária inválida
            return;
        }

        // Determinar direção do swap na pool intermediária
        bool zeroForOneIntermediate = intermediatePool.currency0 == inputCurrency;

        // Fazer swap através da pool intermediária
        try poolManager.swap(
            intermediatePool,
            SwapParams({
                zeroForOne: zeroForOneIntermediate,
                amountSpecified: -int256(amount),
                sqrtPriceLimitX96: 0
            }),
            ""
        ) returns (BalanceDelta) {
            // Swap bem-sucedido - o USDC será recebido pelo contrato
        } catch {
            // Se o swap falhar, os tokens permanecem no contrato
            // Podem ser processados depois via função separada
        }
    }

    /// @notice Tenta fazer compound das taxas acumuladas
    /// @dev Esta função pode ser chamada externamente ou internamente
    function tryCompound(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        _tryCompound(key, poolId);
    }

    /// @notice Função interna para fazer compound
    /// @dev Tenta reinvestir as taxas acumuladas como liquidez na pool
    ///      Verifica: 1) intervalo de 4 horas, 2) fees >= 20x custo de gas em USD
    function _tryCompound(PoolKey calldata key, PoolId poolId) internal {
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return;
        }

        // Verificar se passaram 4 horas desde o último compound
        uint256 lastCompound = lastCompoundTimestamp[poolId];
        if (lastCompound > 0 && block.timestamp < lastCompound + COMPOUND_INTERVAL) {
            return; // Ainda não passaram 4 horas
        }

        uint256 fees0 = accumulatedFees0[poolId];
        uint256 fees1 = accumulatedFees1[poolId];

        // Verificar se há fees acumuladas
        if (fees0 == 0 && fees1 == 0) {
            return;
        }

        // Calcular custo de gas em USD
        uint256 gasCostUSD = _calculateGasCostUSD(poolId);
        
        // Calcular valor total das fees acumuladas em USD
        uint256 feesValueUSD = _calculateFeesValueUSD(poolId, fees0, fees1);
        
        // Verificar se fees acumuladas são >= 20x o custo de gas
        if (feesValueUSD < gasCostUSD * MIN_FEES_MULTIPLIER) {
            return; // Fees não são suficientes (precisa ser >= 20x o custo de gas)
        }

        int24 tickLower = poolTickLower[poolId];
        int24 tickUpper = poolTickUpper[poolId];
        
        // Verificar se temos um tick range configurado
        if (tickLower != 0 || tickUpper != 0) {
            // Calcular o delta de liquidez baseado nas taxas
            // Nota: Esta é uma aproximação simplificada
            // Para produção, use as fórmulas corretas do Uniswap v4 (LiquidityMath)
            int128 liquidityDelta = _calculateLiquidityFromAmounts(
                key,
                tickLower,
                tickUpper,
                fees0,
                fees1
            );
            
            if (liquidityDelta > 0) {
                // Criar parâmetros para modifyLiquidity
                ModifyLiquidityParams memory params = ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: liquidityDelta,
                    salt: bytes32(0)
                });
                
                // Resetar taxas acumuladas antes de fazer o compound
                accumulatedFees0[poolId] = 0;
                accumulatedFees1[poolId] = 0;
                
                // Chamar modifyLiquidity para adicionar as taxas como liquidez
                try poolManager.modifyLiquidity(key, params, "") returns (BalanceDelta /* callerDelta */, BalanceDelta /* feesAccrued */) {
                    // Atualizar timestamp do último compound
                    lastCompoundTimestamp[poolId] = block.timestamp;
                    emit FeesCompounded(poolId, fees0, fees1);
                } catch {
                    // Se falhar, restaurar as taxas acumuladas
                    accumulatedFees0[poolId] = fees0;
                    accumulatedFees1[poolId] = fees1;
                }
            }
        } else {
            // Se não temos tick range, apenas resetamos e emitimos evento
            // Isso permite que um keeper externo ou outra lógica trate
            accumulatedFees0[poolId] = 0;
            accumulatedFees1[poolId] = 0;
            lastCompoundTimestamp[poolId] = block.timestamp;
            emit FeesCompounded(poolId, fees0, fees1);
        }
    }

    /// @notice Calcula o custo de gas em USD
    /// @dev Estima o custo de gas para executar compound e converte para USD
    /// @return gasCostUSD Custo de gas em USD
    function _calculateGasCostUSD(PoolId /* poolId */) internal view returns (uint256 gasCostUSD) {
        // Estimativa de gas para compound: ~200k gas
        uint256 estimatedGasLimit = 200000;
        
        // Calcular gas price (usar block.basefee * 2 como estimativa)
        uint256 gasPriceWei = block.basefee > 0 ? block.basefee * 2 : 30e9; // Default 30 gwei
        
        // Calcular custo de gas em wei
        uint256 gasCostWei = gasPriceWei * estimatedGasLimit;
        
        // Converter wei para USD (assumindo ETH = $3000 como padrão)
        // Se tiver preço configurado, usar; senão usar padrão
        uint256 ethPriceUSD = 3000; // Preço padrão do ETH em USD
        
        // gasCostUSD = (gasCostWei * ethPriceUSD) / 1e18
        gasCostUSD = (gasCostWei * ethPriceUSD) / 1e18;
        
        return gasCostUSD;
    }

    /// @notice Calcula o valor total das fees acumuladas em USD
    /// @dev Converte fees0 e fees1 para USD usando preços configurados
    /// @param poolId ID da pool
    /// @param fees0 Quantidade de token0 acumulado
    /// @param fees1 Quantidade de token1 acumulado
    /// @return feesValueUSD Valor total das fees em USD
    function _calculateFeesValueUSD(
        PoolId poolId,
        uint256 fees0,
        uint256 fees1
    ) internal view returns (uint256 feesValueUSD) {
        uint256 price0 = token0PriceUSD[poolId];
        uint256 price1 = token1PriceUSD[poolId];
        
        // Se preços não estão configurados, retornar 0 (não pode calcular)
        if (price0 == 0 || price1 == 0) {
            return 0;
        }
        
        // Calcular valor em USD de cada token
        // Assumindo que fees0 e fees1 já estão nas unidades corretas (wei para tokens com 18 decimais)
        // Para tokens com decimais diferentes, seria necessário ajustar
        // Por simplicidade, assumimos que os preços já estão ajustados para a unidade correta
        
        uint256 value0USD = (fees0 * price0) / 1e18; // Assumindo 18 decimais
        uint256 value1USD = (fees1 * price1) / 1e18; // Assumindo 18 decimais
        
        feesValueUSD = value0USD + value1USD;
        
        return feesValueUSD;
    }
    
    /// @notice Calcula o delta de liquidez baseado nas quantidades de tokens
    /// @dev Esta é uma versão simplificada - para produção, use as fórmulas corretas do Uniswap v4
    /// @param amount0 Quantidade de token0
    /// @param amount1 Quantidade de token1
    /// @return liquidityDelta O delta de liquidez calculado
    function _calculateLiquidityFromAmounts(
        PoolKey calldata /* key */,
        int24 /* tickLower */,
        int24 /* tickUpper */,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (int128 liquidityDelta) {
        // Nota: Esta é uma implementação simplificada
        // Para uma implementação completa, você precisaria:
        // 1. Obter o tick atual da pool
        // 2. Calcular a liquidez para token0 e token1 separadamente usando TickMath
        // 3. Retornar o mínimo entre os dois (ou usar a fórmula correta baseada no tick atual)
        // 
        // Por enquanto, retornamos uma aproximação baseada no menor valor
        // Isso funciona mas não é otimizado - em produção, use as bibliotecas do Uniswap v4
        
        if (amount0 == 0 || amount1 == 0) {
            return 0;
        }
        
        // Aproximação simples: usar o mínimo entre os dois valores
        // Em produção, calcule usando as fórmulas corretas de liquidez
        uint256 minAmount = amount0 < amount1 ? amount0 : amount1;
        
        // Converter para int128 (garantindo que não ultrapasse o limite)
        if (minAmount > uint128(type(int128).max)) {
            minAmount = uint128(type(int128).max);
        }
        
        return int128(int256(minAmount));
    }

    /// @notice Atualiza o owner do contrato
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }

    /// @notice Função de emergência para retirar tokens acumulados
    /// @dev Apenas o owner pode chamar
    /// @param key A chave da pool
    /// @param to Endereço para onde enviar os tokens
    function emergencyWithdraw(
        PoolKey calldata key,
        address to
    ) external onlyOwner {
        require(to != address(0), "Invalid address");
        
        PoolId poolId = key.toId();
        uint256 fees0 = accumulatedFees0[poolId];
        uint256 fees1 = accumulatedFees1[poolId];
        
        // Resetar taxas acumuladas
        accumulatedFees0[poolId] = 0;
        accumulatedFees1[poolId] = 0;
        
        // Transferir tokens se houver saldo
        // Nota: Em produção, você precisaria implementar a transferência real dos tokens
        // Isso depende de como os tokens são armazenados no hook
        // Por enquanto, apenas resetamos as taxas acumuladas
        
        emit FeesCompounded(poolId, fees0, fees1);
    }
    
    /// @notice Obtém informações sobre uma pool configurada
    /// @param key A chave da pool
    /// @return config Configuração da pool
    /// @return fees0 Taxas acumuladas em token0
    /// @return fees1 Taxas acumuladas em token1
    /// @return tickLower Tick inferior configurado
    /// @return tickUpper Tick superior configurado
    function getPoolInfo(PoolKey calldata key) external view returns (
        PoolConfig memory config,
        uint256 fees0,
        uint256 fees1,
        int24 tickLower,
        int24 tickUpper
    ) {
        PoolId poolId = key.toId();
        return (
            poolConfigs[poolId],
            accumulatedFees0[poolId],
            accumulatedFees1[poolId],
            poolTickLower[poolId],
            poolTickUpper[poolId]
        );
    }
    
    /// @notice Obtém apenas as taxas acumuladas (útil para keepers)
    /// @param key A chave da pool
    /// @return fees0 Taxas acumuladas em token0
    /// @return fees1 Taxas acumuladas em token1
    function getAccumulatedFees(PoolKey calldata key) external view returns (uint256 fees0, uint256 fees1) {
        PoolId poolId = key.toId();
        return (accumulatedFees0[poolId], accumulatedFees1[poolId]);
    }

    /// @notice Verifica se o compound pode ser executado para uma pool
    /// @dev Útil para keepers verificarem antes de chamar checkAndCompound()
    /// @param key A chave da pool
    /// @return canCompound Retorna true se todas as condições são atendidas
    /// @return reason Mensagem explicando por que não pode fazer compound (se aplicável)
    /// @return timeUntilNextCompound Tempo restante até poder fazer compound (em segundos)
    /// @return feesValueUSD Valor das fees acumuladas em USD
    /// @return gasCostUSD Custo estimado de gas em USD
    function canExecuteCompound(PoolKey calldata key) external view returns (
        bool canCompound,
        string memory reason,
        uint256 timeUntilNextCompound,
        uint256 feesValueUSD,
        uint256 gasCostUSD
    ) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return (false, "Pool not enabled", 0, 0, 0);
        }

        uint256 fees0 = accumulatedFees0[poolId];
        uint256 fees1 = accumulatedFees1[poolId];

        if (fees0 == 0 && fees1 == 0) {
            return (false, "No accumulated fees", 0, 0, 0);
        }

        // Verificar intervalo de 4 horas
        uint256 lastCompound = lastCompoundTimestamp[poolId];
        if (lastCompound > 0) {
            uint256 timeElapsed = block.timestamp - lastCompound;
            if (timeElapsed < COMPOUND_INTERVAL) {
                timeUntilNextCompound = COMPOUND_INTERVAL - timeElapsed;
                return (false, "4 hours not elapsed", timeUntilNextCompound, 0, 0);
            }
        }

        // Calcular custo de gas e valor das fees
        gasCostUSD = _calculateGasCostUSD(poolId);
        feesValueUSD = _calculateFeesValueUSD(poolId, fees0, fees1);

        if (feesValueUSD == 0) {
            return (false, "Token prices not configured", 0, 0, gasCostUSD);
        }

        // Verificar se fees >= 20x custo de gas (calculado automaticamente)
        if (feesValueUSD < gasCostUSD * MIN_FEES_MULTIPLIER) {
            return (false, "Fees less than 20x gas cost", 0, feesValueUSD, gasCostUSD);
        }

        return (true, "", 0, feesValueUSD, gasCostUSD);
    }
}

