# Script para finalizar instalação do Foundry após Build Tools
# Execute este script após o Visual Studio Build Tools ser instalado

Write-Host "=== Finalizando Instalação do Foundry ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se Build Tools está instalado
$vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (Test-Path $vsPath) {
    Write-Host "Visual Studio Build Tools encontrado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Instalando Foundry via Cargo..." -ForegroundColor Yellow
    Write-Host "Isso pode levar 15-30 minutos na primeira vez..." -ForegroundColor Cyan
    Write-Host ""
    
    cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=== Foundry Instalado com Sucesso! ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Feche e reabra o PowerShell, depois execute:" -ForegroundColor Yellow
        Write-Host "  cd C:\Users\derek\amebacrypto" -ForegroundColor White
        Write-Host "  forge --version" -ForegroundColor White
        Write-Host "  forge test" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Erro na instalação. Verifique as mensagens acima." -ForegroundColor Red
    }
} else {
    Write-Host "Visual Studio Build Tools não encontrado." -ForegroundColor Red
    Write-Host "Por favor, aguarde a conclusão da instalação do Build Tools." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ou use o WSL após reiniciar (mais fácil):" -ForegroundColor Cyan
    Write-Host "  1. Reinicie o Windows" -ForegroundColor White
    Write-Host "  2. Execute: wsl" -ForegroundColor White
    Write-Host "  3. No WSL: curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
    Write-Host "  4. No WSL: foundryup" -ForegroundColor White
}


