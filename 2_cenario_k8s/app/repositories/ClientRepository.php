<?php

class ClientRepository
{
    private PDO $pdo;

    public function __construct(PDO $pdo = null)
    {
        $this->pdo = $pdo ?? Database::getConnection();
    }

    public function list(): array
    {
        $stmt = $this->pdo->query('SELECT id, name, email, created_at FROM clients ORDER BY id ASC');
        return $stmt->fetchAll();
    }

    public function findById(int $id): ?array
    {
        $stmt = $this->pdo->prepare('SELECT id, name, email, created_at FROM clients WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $client = $stmt->fetch();
        return $client ?: null;
    }
}
