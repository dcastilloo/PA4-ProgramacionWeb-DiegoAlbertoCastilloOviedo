<?php
declare(strict_types=1);
namespace App\Controllers;
use PDO;
use App\Models\Reserva;

final class ReservaController extends CrudController
{
    public function __construct(PDO $db)
    {
        parent::__construct(new Reserva($db));
    }
}
