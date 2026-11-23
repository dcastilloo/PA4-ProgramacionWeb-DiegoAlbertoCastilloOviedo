<?php
declare(strict_types=1);
namespace Core;
use PDOException;

final class ErrorHandler
{
    public static function handle(\Throwable $error): never
    {
        if ($error instanceof ApiException) {
            Response::error($error->getMessage(), $error->status);
        }
        if ($error instanceof PDOException) {
            $number = (int) ($error->errorInfo[1] ?? 0);
            $messages = [
                51001 => 'El importe debe ser positivo.',
                51002 => 'El paciente no existe o está inactivo.',
                51003 => 'El servicio no existe o está inactivo.',
                51004 => 'El bloque no existe o está deshabilitado.',
                51005 => 'La cita debe tener fecha y hora futuras.',
                51006 => 'El bloque ya tiene una reserva vigente.',
                51010 => 'Solo puede pagarse una reserva pendiente.',
                51011 => 'El pago debe coincidir con el importe de la reserva.',
                51012 => 'El medio de pago no existe o está inactivo.',
                51013 => 'La referencia de pago no es válida.',
                51020 => 'Solo puede cancelarse una reserva pendiente.',
                51021 => 'No puede cancelarse una reserva con pago vigente.',
                51030 => 'Solo puede modificarse una reserva pendiente sin pago vigente.',
                51031 => 'La reserva no existe.',
                51040 => 'El pago no existe.',
                51041 => 'El pago ya está anulado o su reserva no está confirmada.',
                51042 => 'Solo puede corregirse o anularse un pago de una cita futura.',
            ];
            if (isset($messages[$number])) {
                Response::error($messages[$number], in_array($number, [51031, 51040], true) ? 404 : 409);
            }
            if (in_array($number, [2601, 2627], true)) {
                Response::error('Ya existe un registro con ese valor único.', 409);
            }
            if ($number === 547) {
                Response::error('La operación entra en conflicto con una relación o restricción de datos.', 409);
            }
            if (in_array($number, [1205, 1222], true)) {
                Response::error('Conflicto con otra operación concurrente. Inténtelo nuevamente.', 409);
            }
        }
        // No registrar el mensaje del driver: puede contener datos de conexión.
        error_log('PA4: error interno de tipo ' . get_class($error));
        Response::error('No fue posible completar la operación. Revise la configuración o contacte al administrador.', 500);
    }
}
