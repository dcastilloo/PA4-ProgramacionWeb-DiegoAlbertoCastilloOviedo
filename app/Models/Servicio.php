<?php
declare(strict_types=1);
namespace App\Models;
final class Servicio extends CatalogModel
{
    protected string $table = 'Servicio';
    protected string $key = 'ServicioID';
    public array $schema = ['Nombre' => ['text', 3, 80], 'Descripcion' => ['text', 1, 250], 'Activo' => ['bool']];
    public array $defaults = ['Activo' => true];
}
