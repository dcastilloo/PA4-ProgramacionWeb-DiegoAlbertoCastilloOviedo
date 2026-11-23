<?php
declare(strict_types=1);
namespace App\Models;
final class MedioPago extends CatalogModel
{
    protected string $table = 'MedioPago';
    protected string $key = 'MedioPagoID';
    public array $schema = ['Nombre' => ['text', 3, 50], 'Activo' => ['bool']];
    public array $defaults = ['Activo' => true];
}
