<?php
declare(strict_types=1);
namespace Config;

final class Environment
{
    public static function load(string $path): void
    {
        if (!is_file($path)) {
            return;
        }
        foreach (file($path, FILE_IGNORE_NEW_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }
            [$key, $value] = array_pad(explode('=', $line, 2), 2, '');
            $key = trim($key);
            if (preg_match('/^[A-Z_][A-Z0-9_]*$/D', $key) && getenv($key) === false) {
                putenv($key . '=' . trim($value, " \t\n\r\0\x0B\"'"));
            }
        }
    }

    public static function get(string $key, string $default = ''): string
    {
        $value = getenv($key);
        return $value === false ? $default : $value;
    }
}
