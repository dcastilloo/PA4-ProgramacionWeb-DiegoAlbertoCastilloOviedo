param(
    [string]$Php = 'C:/xampp/php/php.exe',
    [string]$PaqueteSqlsrv = '',
    [string]$ComposerPhar = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $projectRoot '.runtime'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
if (-not (Test-Path -LiteralPath $Php)) { throw 'Indique -Php con la ruta de PHP 8.2 TS x64.' }
$Php = (Resolve-Path -LiteralPath $Php).Path
$build = & $Php -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION,"|",PHP_ZTS,"|",PHP_INT_SIZE;'
if ($build -ne '8.2|1|8') { throw 'Este asistente corresponde a PHP 8.2 TS x64. Para otro PHP configure pdo_sqlsrv según su matriz de compatibilidad.' }
$driverZip = Join-Path $runtimeDir 'sqlsrv-5.12.0.zip'
if ($PaqueteSqlsrv) {
    Copy-Item -LiteralPath $PaqueteSqlsrv -Destination $driverZip -Force
} elseif (-not (Test-Path -LiteralPath $driverZip)) {
    Invoke-WebRequest -Uri 'https://github.com/microsoft/msphpsql/releases/download/v5.12.0/Windows_5.12.0RTW.zip' -OutFile $driverZip
}
if ((Get-FileHash -LiteralPath $driverZip -Algorithm SHA256).Hash -ne '48C2067C8FC4683418D3096807AF92A65660245BE846A61BB65F93D28272FF71') {
    throw 'El paquete del controlador no coincide con el SHA256 esperado.'
}
$driverDir = Join-Path $runtimeDir 'sqlsrv'
Expand-Archive -LiteralPath $driverZip -DestinationPath $driverDir -Force
$driver = Join-Path $driverDir 'Windows/php_pdo_sqlsrv_82_ts_x64.dll'
$composer = Join-Path $runtimeDir 'composer.phar'
if ($ComposerPhar) {
    Copy-Item -LiteralPath $ComposerPhar -Destination $composer -Force
} elseif (-not (Test-Path -LiteralPath $composer)) {
    Invoke-WebRequest -Uri 'https://getcomposer.org/download/2.11.2/composer.phar' -OutFile $composer
}
if ((Get-FileHash -LiteralPath $composer -Algorithm SHA256).Hash -ne 'DD158C0AFD41D15FAC89E1B4E47B5D42911FE316C3687CD5EDAC98319B25D028') {
    throw 'Composer no coincide con el SHA256 esperado.'
}
$config = @{ Php = $Php; Driver = $driver }
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeDir 'config.json') -Encoding utf8
& $Php -d "extension=$driver" $composer install "--working-dir=$projectRoot" --no-interaction --no-dev
if ($LASTEXITCODE -ne 0) { throw 'Composer no pudo completar la instalación.' }
$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot '.env.example') -Destination $envFile
}
Write-Host 'Entorno preparado. Revise .env, instale database/01_instalar.sql y ejecute scripts/iniciar.ps1.'
