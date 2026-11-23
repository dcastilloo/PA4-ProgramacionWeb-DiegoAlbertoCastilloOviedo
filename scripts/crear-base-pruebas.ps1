param([string]$Servidor = 'localhost')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workDir = Join-Path $projectRoot '.work'
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'database/01_instalar.sql') -Raw
$destination = Join-Path $workDir 'instalar-pruebas.sql'
$source.Replace('PA4_3657_ConsultorioIris', 'PA4_3657_ConsultorioIris_Pruebas') | Set-Content -LiteralPath $destination -Encoding utf8
& sqlcmd -S $Servidor -E -b -f 65001 -i $destination
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base de pruebas.' }
