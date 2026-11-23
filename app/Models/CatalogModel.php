<?php
declare(strict_types=1);
namespace App\Models;
use Core\ApiException;

abstract class CatalogModel extends CrudModel
{
    protected function canDeactivate(int $id): void
    {
        if ($this->table === 'MedioPago') {
            $sql = 'SELECT COUNT(*) FROM dbo.Pago WITH (HOLDLOCK) WHERE MedioPagoID = ? AND Anulado = 0';
        } else {
            $sql = "SELECT COUNT(*) FROM dbo.Reserva WITH (HOLDLOCK) WHERE {$this->key} = ? AND Estado <> 'CANCELADA'";
        }
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$id]);
        $count = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        if ($count > 0) { throw new ApiException(409, 'El registro tiene operaciones vigentes y no puede darse de baja.'); }
    }

    public function create(array $data): array
    {
        $fields = implode(', ', array_keys($data));
        $slots = implode(', ', array_fill(0, count($data), '?'));
        $stmt = $this->db->prepare("INSERT dbo.{$this->table} ($fields) OUTPUT INSERTED.{$this->key} VALUES ($slots)");
        $stmt->execute(array_values($data));
        $id = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        return $this->find($id);
    }

    public function update(int $id, array $data): array
    {
        return $this->transaction(function () use ($id, $data) {
            $this->find($id, true);
            if (!$data['Activo']) { $this->canDeactivate($id); }
            $fields = implode(', ', array_map(fn ($field) => "$field = ?", array_keys($data)));
            $stmt = $this->db->prepare("UPDATE dbo.{$this->table} SET $fields WHERE {$this->key} = ?");
            $stmt->execute([...array_values($data), $id]);
            return $this->find($id);
        });
    }

    public function delete(int $id): array
    {
        return $this->transaction(function () use ($id) {
            $row = $this->find($id, true);
            if (!$row['Activo']) { throw new ApiException(409, 'El registro ya está inactivo.'); }
            $this->canDeactivate($id);
            $stmt = $this->db->prepare("UPDATE dbo.{$this->table} SET Activo = 0 WHERE {$this->key} = ?");
            $stmt->execute([$id]);
            return $this->find($id);
        });
    }
}
