<?php
declare(strict_types=1);
namespace Config;
use PDO;

final class Database
{
    public static function connect(): PDO
    {
        // Los datos de conexión proceden del entorno, nunca del código fuente.
        $server = Environment::get('DB_SERVER', 'localhost');
        $database = Environment::get('DB_DATABASE', 'PA4_3657_ConsultorioIris');
        foreach ([$server, $database] as $value) {
            if (!preg_match('/^[\w.,\\\\-]+$/D', $value)) {
                throw new \RuntimeException('Configuración de conexión inválida.');
            }
        }
        $trust = Environment::get('DB_TRUST_CERTIFICATE', '0') === '1' ? '1' : '0';
        $dsn = "sqlsrv:Server=$server;Database=$database;Encrypt=1;TrustServerCertificate=$trust;LoginTimeout=5";
        $user = Environment::get('DB_USERNAME');
        $password = Environment::get('DB_PASSWORD');
        return new PDO($dsn, $user === '' ? null : $user, $user === '' ? null : $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::SQLSRV_ATTR_ENCODING => PDO::SQLSRV_ENCODING_UTF8,
            PDO::SQLSRV_ATTR_FETCHES_NUMERIC_TYPE => true,
        ]);
    }
}
