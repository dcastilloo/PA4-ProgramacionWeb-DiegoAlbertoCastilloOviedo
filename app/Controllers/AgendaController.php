<?php
declare(strict_types=1);
namespace App\Controllers;
use PDO;
use App\Models\Agenda;

final class AgendaController extends CrudController
{
    public function __construct(PDO $db)
    {
        parent::__construct(new Agenda($db));
    }
}
