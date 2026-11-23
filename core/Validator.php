<?php
declare(strict_types=1);
namespace Core;

final class Validator
{
    public static function validate(array $data, array $schema): array
    {
        if (array_diff(array_keys($data), array_keys($schema))) {
            throw new ApiException(400, 'La solicitud contiene campos desconocidos o no editables.');
        }
        $clean = [];
        foreach ($schema as $name => $rule) {
            if (!array_key_exists($name, $data)) {
                throw new ApiException(400, "El campo $name es obligatorio.");
            }
            $v = $data[$name];
            $ok = false;
            if ($rule[0] === 'text') {
                if (is_string($v)) {
                    $v = trim($v);
                    // NVARCHAR limita unidades UTF-16, no solo caracteres Unicode.
                    $len = strlen(mb_convert_encoding($v, 'UTF-16LE', 'UTF-8')) / 2;
                    $ok = $len >= $rule[1] && $len <= $rule[2] && !preg_match('/[\x00-\x1F\x7F]/u', $v);
                }
            } elseif ($rule[0] === 'email') {
                if (is_string($v)) {
                    $v = trim($v);
                    $ok = strlen($v) <= 120 && filter_var($v, FILTER_VALIDATE_EMAIL) !== false;
                }
            } elseif ($rule[0] === 'id') {
                $ok = is_int($v) && $v > 0 && $v <= ($rule[1] ?? 2147483647);
            } elseif ($rule[0] === 'bool') {
                $ok = is_bool($v);
                if ($ok) { $v = (int) $v; }
            } elseif ($rule[0] === 'money') {
                // Los decimales viajan como cadenas para conservar los centavos.
                $ok = is_string($v) && preg_match('/^(?:0|[1-9][0-9]{0,7})\.[0-9]{2}$/D', $v) && (float) $v > 0;
            } elseif ($rule[0] === 'date') {
                if (is_string($v)) {
                    $date = \DateTimeImmutable::createFromFormat('!Y-m-d\TH:i:s', $v);
                    $ok = $date && $date->format('Y-m-d\TH:i:s') === $v && substr($v, 14) === '00:00'
                        && $v >= '0001-01-01T00:00:00' && $v <= '9999-12-31T22:00:00';
                }
            }
            if (!$ok) {
                throw new ApiException(400, "El campo $name no cumple el tipo, formato o longitud permitidos.");
            }
            $clean[$name] = $v;
        }
        return $clean;
    }
}
