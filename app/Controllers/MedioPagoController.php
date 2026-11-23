<?php
declare(strict_types=1);
namespace App\Controllers;
use PDO;
use App\Models\MedioPago;

final class MedioPagoController extends CrudController
{
    public function __construct(PDO $db)
    {
        parent::__construct(new MedioPago($db));
    }
}
