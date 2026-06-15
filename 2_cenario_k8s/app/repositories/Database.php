<?php

class Database
{
    public static function getConnection(): PDO
    {
        $host = getenv('DB_HOST') ?: 'mysql';
        $name = getenv('DB_NAME') ?: 'appdb';
        $user = getenv('DB_USER') ?: 'appuser';
        $pass = getenv('DB_PASS') ?: 'apppass';
        $dsn = sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', $host, $name);

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ];

        return new PDO($dsn, $user, $pass, $options);
    }
}
