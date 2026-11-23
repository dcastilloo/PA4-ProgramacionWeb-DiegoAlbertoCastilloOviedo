<?php
declare(strict_types=1);
namespace App\Controllers;
use PDO;
use App\Models\Pago;

final class PagoController extends CrudController
{
    public function __construct(PDO $db)
    {
        parent::__construct(new Pago($db));
    }
}
