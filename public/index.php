<?php
declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('log_errors', '1');
date_default_timezone_set('America/Lima');
require __DIR__ . '/../vendor/autoload.php';
set_exception_handler([Core\ErrorHandler::class, 'handle']);
Config\Environment::load(__DIR__ . '/../.env');
$db = Config\Database::connect();
$router = new Core\Router();
require __DIR__ . '/../routes/api.php';
$router->dispatch($_SERVER['REQUEST_METHOD'], $_SERVER['REQUEST_URI']);
