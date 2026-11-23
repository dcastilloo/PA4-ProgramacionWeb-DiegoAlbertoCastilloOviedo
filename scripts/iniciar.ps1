param([ValidateRange(1024, 65535)][int]$Puerto = 8084)
& "$PSScriptRoot/php.ps1" -Argumentos @('-S', "127.0.0.1:$Puerto", '-t', 'public', 'public/index.php')
