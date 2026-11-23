<?php
declare(strict_types=1);
namespace Core;

final class Request
{
    public static function body(): array
    {
        if (strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0])) !== 'application/json') {
            throw new ApiException(415, 'Envíe Content-Type: application/json.');
        }
        $stream = fopen('php://input', 'rb');
        $input = stream_get_contents($stream, 65537);
        fclose($stream);
        if (strlen($input) > 65536) {
            throw new ApiException(413, 'La solicitud supera el tamaño permitido.');
        }
        try {
            $data = json_decode($input, false, 32, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            throw new ApiException(400, 'El cuerpo contiene JSON inválido.');
        }
        if (!$data instanceof \stdClass) {
            throw new ApiException(400, 'El cuerpo debe ser un objeto JSON.');
        }
        return (array) $data;
    }

    public static function id(string $value): int
    {
        if (!preg_match('/^[1-9][0-9]{0,9}$/D', $value) || (float) $value > 2147483647) {
            throw new ApiException(400, 'El identificador debe ser un entero positivo válido.');
        }
        return (int) $value;
    }
}
