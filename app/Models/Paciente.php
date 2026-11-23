<?php
declare(strict_types=1);
namespace App\Models;
final class Paciente extends CatalogModel
{
    protected string $table = 'Paciente';
    protected string $key = 'PacienteID';
    public array $schema = ['NombreCompleto' => ['text', 3, 80], 'Correo' => ['email'], 'Activo' => ['bool']];
    public array $defaults = ['Activo' => true];
}
