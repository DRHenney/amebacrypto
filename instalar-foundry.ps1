# Script de Instalação do Foundry para Windows
# Este script tenta instalar o Foundry usando diferentes métodos

Write-Host "=== Instalação do Foundry para Windows ===" -ForegroundColor Cyan
Write-Host ""

# Método 1: Tentar instalar via WSL (Recomendado)
Write-Host "Método 1: Verificando WSL..." -ForegroundColor Yellow
$wslInstalled = $false
try {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
        Write-Host "WSL está instalado!" -ForegroundColor Green
    }
} catch {
    Write-Host "WSL não está instalado." -ForegroundColor Yellow
}

if ($wslInstalled) {
    Write-Host ""
    Write-Host "Instalando Foundry via WSL..." -ForegroundColor Yellow
    Write-Host "Execute os seguintes comandos no WSL:" -ForegroundColor Cyan
    Write-Host "  curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
    Write-Host "  foundryup" -ForegroundColor White
    Write-Host ""
    $installWSL = Read-Host "Deseja abrir o WSL agora para instalar? (S/N)"
    if ($installWSL -eq "S" -or $installWSL -eq "s") {
        wsl bash -c "curl -L https://foundry.paradigm.xyz | bash && foundryup"
    }
} else {
    Write-Host ""
    Write-Host "WSL não está instalado. Deseja instalar o WSL?" -ForegroundColor Yellow
    Write-Host "O WSL é a forma recomendada de usar o Foundry no Windows." -ForegroundColor Cyan
    $installWSL = Read-Host "Instalar WSL agora? (S/N) - Requer reinicialização"
    
    if ($installWSL -eq "S" -or $installWSL -eq "s") {
        Write-Host "Instalando WSL..." -ForegroundColor Yellow
        wsl --install
        Write-Host ""
        Write-Host "WSL será instalado. Após a reinicialização, execute este script novamente." -ForegroundColor Green
        Write-Host "Ou execute manualmente no WSL:" -ForegroundColor Cyan
        Write-Host "  curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
        Write-Host "  foundryup" -ForegroundColor White
        exit
    }
}

# Método 2: Tentar baixar binários pré-compilados (se disponíveis)
Write-Host ""
Write-Host "Método 2: Tentando baixar binários pré-compilados..." -ForegroundColor Yellow

$foundryDir = "$env:USERPROFILE\.foundry"
$foundryBinDir = "$foundryDir\bin"

# Criar diretório se não existir
if (-not (Test-Path $foundryDir)) {
    New-Item -ItemType Directory -Path $foundryDir -Force | Out-Null
}
if (-not (Test-Path $foundryBinDir)) {
    New-Item -ItemType Directory -Path $foundryBinDir -Force | Out-Null
}

# Tentar baixar de uma release específica
$ProgressPreference = 'SilentlyContinue'
$foundryZip = "$env:TEMP\foundry.zip"

# URLs possíveis para tentar
$urls = @(
    "https://github.com/foundry-rs/foundry/releases/download/nightly-2025-01-25/foundry_nightly_x86_64-pc-windows-msvc.zip",
    "https://github.com/foundry-rs/foundry/releases/download/nightly-2025-01-24/foundry_nightly_x86_64-pc-windows-msvc.zip"
)

$downloaded = $false
foreach ($url in $urls) {
    try {
        Write-Host "Tentando baixar de: $url" -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $foundryZip -ErrorAction Stop
        $downloaded = $true
        Write-Host "Download bem-sucedido!" -ForegroundColor Green
        break
    } catch {
        Write-Host "Falha ao baixar desta URL." -ForegroundColor Gray
        continue
    }
}

if ($downloaded) {
    Write-Host "Extraindo arquivos..." -ForegroundColor Yellow
    Expand-Archive -Path $foundryZip -DestinationPath $foundryBinDir -Force
    Remove-Item $foundryZip -Force
    
    # Adicionar ao PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$foundryBinDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$foundryBinDir", "User")
        Write-Host "Adicionado ao PATH do usuário." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Foundry instalado com sucesso!" -ForegroundColor Green
    Write-Host "IMPORTANTE: Feche e reabra o PowerShell para usar os comandos forge, cast e anvil." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Não foi possível baixar binários pré-compilados." -ForegroundColor Red
    Write-Host ""
    Write-Host "=== Opções de Instalação ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. INSTALAÇÃO VIA WSL (Recomendado):" -ForegroundColor Yellow
    Write-Host "   - Execute: wsl --install" -ForegroundColor White
    Write-Host "   - Após reiniciar, no WSL execute:" -ForegroundColor White
    Write-Host "     curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
    Write-Host "     foundryup" -ForegroundColor White
    Write-Host ""
    Write-Host "2. INSTALAÇÃO VIA RUST/CARGO:" -ForegroundColor Yellow
    Write-Host "   - Instale o Rust: https://rustup.rs/" -ForegroundColor White
    Write-Host "   - Depois execute: cargo install --git https://github.com/foundry-rs/foundry foundry-cli anvil cast forge chisel --locked" -ForegroundColor White
    Write-Host ""
    Write-Host "3. USAR GITPOD OU CODESPACES:" -ForegroundColor Yellow
    Write-Host "   - Desenvolva em um ambiente Linux na nuvem" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Write-Host "Para mais informações, visite: https://book.getfoundry.sh/getting-started/installation" -ForegroundColor Cyan


