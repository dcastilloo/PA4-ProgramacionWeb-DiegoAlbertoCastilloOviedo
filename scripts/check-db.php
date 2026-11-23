<?php
declare(strict_types=1);
require __DIR__ . '/../vendor/autoload.php';
Config\Environment::load(__DIR__ . '/../.env');
try {
    $db = Config\Database::connect();
    echo json_encode($db->query('SELECT DB_NAME() AS BaseDatos, COUNT(*) AS Tablas FROM sys.tables')->fetch(), JSON_UNESCAPED_UNICODE), PHP_EOL;
} catch (Throwable $error) {
    fwrite(STDERR, 'No se pudo conectar. Verifique el entorno y el controlador PDO de SQL Server.' . PHP_EOL);
    exit(1);
}
