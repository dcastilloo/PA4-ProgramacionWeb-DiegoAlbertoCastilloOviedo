<?php
declare(strict_types=1);
namespace Core;

// Conserva el registro explícito y despacho por método/ruta de la referencia.
final class Router
{
    private array $routes = [];

    public function add(string $method, string $path, callable $action): void
    {
        $this->routes[] = [$method, $path, $action];
    }

    public function dispatch(string $method, string $uri): never
    {
        $path = rtrim(rawurldecode(parse_url($uri, PHP_URL_PATH) ?: '/'), '/') ?: '/';
        $allowed = [];
        foreach ($this->routes as [$verb, $route, $action]) {
            $pattern = '#^' . str_replace('\\{id\\}', '([^/]+)', preg_quote($route, '#')) . '$#D';
            if (preg_match($pattern, $path, $matches)) {
                $allowed[] = $verb;
                if ($verb === $method) {
                    array_shift($matches);
                    $action(...$matches);
                    throw new \LogicException('El controlador no produjo una respuesta.');
                }
            }
        }
        if ($allowed !== []) {
            header('Allow: ' . implode(', ', array_unique($allowed)));
            throw new ApiException(405, 'Método HTTP no permitido para esta ruta.');
        }
        throw new ApiException(404, 'Ruta no encontrada.');
    }
}
