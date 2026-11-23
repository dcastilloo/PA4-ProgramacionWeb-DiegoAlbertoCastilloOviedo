<?php
declare(strict_types=1);
namespace App\Models;
use Core\ApiException;

final class Agenda extends CrudModel
{
    protected string $table = 'Agenda';
    protected string $key = 'AgendaID';
    public array $schema = ['Inicio' => ['date'], 'Habilitada' => ['bool']];
    public array $defaults = ['Habilitada' => true];

    private function future(string $date): void
    {
        $stmt = $this->db->prepare('SELECT CASE WHEN CAST(? AS datetime2) > SYSDATETIME() THEN 1 ELSE 0 END');
        $stmt->execute([$date]);
        $valid = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        if (!$valid) { throw new ApiException(409, 'El inicio de agenda debe estar en el futuro.'); }
    }

    private function available(int $id): void
    {
        $stmt = $this->db->prepare("SELECT COUNT(*) FROM dbo.Reserva WITH (HOLDLOCK) WHERE AgendaID = ? AND Estado <> 'CANCELADA'");
        $stmt->execute([$id]);
        $count = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        if ($count > 0) { throw new ApiException(409, 'La agenda tiene una reserva vigente y no puede modificarse.'); }
    }

    public function create(array $data): array
    {
        $this->future($data['Inicio']);
        $stmt = $this->db->prepare('INSERT dbo.Agenda (Inicio, Habilitada) OUTPUT INSERTED.AgendaID VALUES (?, ?)');
        $stmt->execute([$data['Inicio'], $data['Habilitada']]);
        $id = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        return $this->find($id);
    }

    public function update(int $id, array $data): array
    {
        return $this->transaction(function () use ($id, $data) {
            $this->find($id, true);
            $this->available($id);
            $this->future($data['Inicio']);
            $stmt = $this->db->prepare('UPDATE dbo.Agenda SET Inicio = ?, Habilitada = ? WHERE AgendaID = ?');
            $stmt->execute([$data['Inicio'], $data['Habilitada'], $id]);
            return $this->find($id);
        });
    }

    public function delete(int $id): array
    {
        return $this->transaction(function () use ($id) {
            $row = $this->find($id, true);
            if (!$row['Habilitada']) { throw new ApiException(409, 'El bloque ya está deshabilitado.'); }
            $this->available($id);
            $stmt = $this->db->prepare('UPDATE dbo.Agenda SET Habilitada = 0 WHERE AgendaID = ?');
            $stmt->execute([$id]);
            return $this->find($id);
        });
    }
}
