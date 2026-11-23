param([Parameter(Mandatory = $true)][string[]]$Argumentos)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configFile = Join-Path $projectRoot '.runtime/config.json'
if (-not (Test-Path -LiteralPath $configFile)) { throw 'Ejecute primero scripts/preparar-local.ps1.' }
$runtimeConfig = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
Push-Location -LiteralPath $projectRoot
try {
    & $runtimeConfig.Php -d "extension=$($runtimeConfig.Driver)" @Argumentos
    exit $LASTEXITCODE
} finally { Pop-Location }
