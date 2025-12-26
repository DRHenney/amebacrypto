# Script Completo de Instalação do Foundry
# Este script instala todas as dependências necessárias

Write-Host "=== Instalação Completa do Foundry ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se Visual Studio Build Tools está instalado
Write-Host "Verificando Visual Studio Build Tools..." -ForegroundColor Yellow
$vsBuildTools = Get-Command "cl.exe" -ErrorAction SilentlyContinue

if (-not $vsBuildTools) {
    Write-Host "Visual Studio Build Tools não encontrado." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OPÇÃO 1: Instalar Visual Studio Build Tools (Recomendado para compilar no Windows)" -ForegroundColor Cyan
    Write-Host "  Execute este comando como Administrador:" -ForegroundColor White
    Write-Host "  winget install Microsoft.VisualStudio.2022.BuildTools --override '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools'" -ForegroundColor Green
    Write-Host ""
    Write-Host "OPÇÃO 2: Usar WSL (Mais fácil e recomendado)" -ForegroundColor Cyan
    Write-Host "  Após reiniciar o Windows (WSL já está configurado):" -ForegroundColor White
    Write-Host "  1. Abra o PowerShell" -ForegroundColor White
    Write-Host "  2. Execute: wsl" -ForegroundColor Green
    Write-Host "  3. No WSL execute:" -ForegroundColor White
    Write-Host "     curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor Green
    Write-Host "     foundryup" -ForegroundColor Green
    Write-Host ""
    
    $escolha = Read-Host "Deseja instalar Visual Studio Build Tools agora? (S/N)"
    if ($escolha -eq "S" -or $escolha -eq "s") {
        Write-Host "Instalando Visual Studio Build Tools..." -ForegroundColor Yellow
        Write-Host "Isso pode demorar vários minutos..." -ForegroundColor Yellow
        Start-Process winget -ArgumentList "install Microsoft.VisualStudio.2022.BuildTools --override '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools'" -Verb RunAs -Wait
        Write-Host ""
        Write-Host "Build Tools instalado! Feche e reabra o PowerShell e execute:" -ForegroundColor Green
        Write-Host "  cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked" -ForegroundColor White
    }
} else {
    Write-Host "Visual Studio Build Tools encontrado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Instalando Foundry via Cargo..." -ForegroundColor Yellow
    Write-Host "Isso pode demorar vários minutos..." -ForegroundColor Yellow
    cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked
}

Write-Host ""
Write-Host "=== Instruções Finais ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Após a instalação, feche e reabra o PowerShell e execute:" -ForegroundColor Yellow
Write-Host "  cd C:\Users\derek\amebacrypto" -ForegroundColor White
Write-Host "  forge --version" -ForegroundColor White
Write-Host "  forge test" -ForegroundColor White


