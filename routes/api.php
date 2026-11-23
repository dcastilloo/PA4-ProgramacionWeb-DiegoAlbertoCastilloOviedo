<?php
declare(strict_types=1);

// Cada módulo declara las cinco operaciones de la consigna.
$controller = new App\Controllers\PacienteController($db);
$router->add('GET', '/api/pacientes', [$controller, 'index']);
$router->add('GET', '/api/pacientes/{id}', [$controller, 'show']);
$router->add('POST', '/api/pacientes', [$controller, 'store']);
$router->add('PUT', '/api/pacientes/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/pacientes/{id}', [$controller, 'destroy']);

$controller = new App\Controllers\ServicioController($db);
$router->add('GET', '/api/servicios', [$controller, 'index']);
$router->add('GET', '/api/servicios/{id}', [$controller, 'show']);
$router->add('POST', '/api/servicios', [$controller, 'store']);
$router->add('PUT', '/api/servicios/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/servicios/{id}', [$controller, 'destroy']);

$controller = new App\Controllers\AgendaController($db);
$router->add('GET', '/api/agenda', [$controller, 'index']);
$router->add('GET', '/api/agenda/{id}', [$controller, 'show']);
$router->add('POST', '/api/agenda', [$controller, 'store']);
$router->add('PUT', '/api/agenda/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/agenda/{id}', [$controller, 'destroy']);

$controller = new App\Controllers\ReservaController($db);
$router->add('GET', '/api/reservas', [$controller, 'index']);
$router->add('GET', '/api/reservas/{id}', [$controller, 'show']);
$router->add('POST', '/api/reservas', [$controller, 'store']);
$router->add('PUT', '/api/reservas/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/reservas/{id}', [$controller, 'destroy']);

$controller = new App\Controllers\MedioPagoController($db);
$router->add('GET', '/api/medios-pago', [$controller, 'index']);
$router->add('GET', '/api/medios-pago/{id}', [$controller, 'show']);
$router->add('POST', '/api/medios-pago', [$controller, 'store']);
$router->add('PUT', '/api/medios-pago/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/medios-pago/{id}', [$controller, 'destroy']);

$controller = new App\Controllers\PagoController($db);
$router->add('GET', '/api/pagos', [$controller, 'index']);
$router->add('GET', '/api/pagos/{id}', [$controller, 'show']);
$router->add('POST', '/api/pagos', [$controller, 'store']);
$router->add('PUT', '/api/pagos/{id}', [$controller, 'update']);
$router->add('DELETE', '/api/pagos/{id}', [$controller, 'destroy']);
