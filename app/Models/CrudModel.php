<?php
declare(strict_types=1);
namespace App\Models;
use PDO;
use Core\ApiException;

abstract class CrudModel
{
    protected string $table;
    protected string $key;
    public array $schema;
    public array $defaults = [];

    public function __construct(protected PDO $db) {}

    public function all(): array
    {
        // Los nombres de tabla/columna son constantes del modelo, no entradas HTTP.
        return $this->db->query("SELECT * FROM dbo.{$this->table} ORDER BY {$this->key}")->fetchAll();
    }

    public function find(int $id, bool $lock = false): array
    {
        $hint = $lock ? ' WITH (UPDLOCK, HOLDLOCK)' : '';
        $stmt = $this->db->prepare("SELECT * FROM dbo.{$this->table}$hint WHERE {$this->key} = ?");
        $stmt->bindValue(1, $id, PDO::PARAM_INT);
        $stmt->execute();
        $row = $stmt->fetch();
        $stmt->closeCursor();
        if (!$row) { throw new ApiException(404, 'Registro no encontrado.'); }
        return $row;
    }

    protected function transaction(callable $operation): mixed
    {
        $this->db->beginTransaction();
        try {
            $result = $operation();
            $this->db->commit();
            return $result;
        } catch (\Throwable $error) {
            if ($this->db->inTransaction()) { $this->db->rollBack(); }
            throw $error;
        }
    }

    protected function procedure(string $sql, array $args): void
    {
        $stmt = $this->db->prepare($sql);
        $stmt->execute($args);
        while ($stmt->nextRowset()) {}
        $stmt->closeCursor();
    }

    abstract public function create(array $data): array;
    abstract public function update(int $id, array $data): array;
    abstract public function delete(int $id): array;
}
