<?php
declare(strict_types=1);
namespace App\Controllers;
use PDO;
use App\Models\Paciente;

final class PacienteController extends CrudController
{
    public function __construct(PDO $db)
    {
        parent::__construct(new Paciente($db));
    }
}
