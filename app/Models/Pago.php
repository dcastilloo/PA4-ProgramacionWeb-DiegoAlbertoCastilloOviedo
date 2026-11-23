<?php
declare(strict_types=1);
namespace App\Models;

final class Pago extends CrudModel
{
    protected string $table = 'Pago';
    protected string $key = 'PagoID';
    public array $schema = ['ReservaID' => ['id'], 'MedioPagoID' => ['id', 255], 'Importe' => ['money'], 'Referencia' => ['text', 4, 40]];
    public array $updateSchema = ['MedioPagoID' => ['id', 255], 'Referencia' => ['text', 4, 40]];

    public function create(array $data): array
    {
        $this->procedure('EXEC dbo.usp_RegistrarPago ?, ?, ?, ?', [$data['ReservaID'], $data['MedioPagoID'], $data['Importe'], $data['Referencia']]);
        $stmt = $this->db->prepare('SELECT PagoID FROM dbo.Pago WHERE Referencia = ?');
        $stmt->execute([$data['Referencia']]);
        $id = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        return $this->find($id);
    }

    public function update(int $id, array $data): array
    {
        $this->procedure('EXEC dbo.usp_ActualizarPago ?, ?, ?', [$id, $data['MedioPagoID'], $data['Referencia']]);
        return $this->find($id);
    }

    public function delete(int $id): array
    {
        $this->procedure('EXEC dbo.usp_AnularPago ?', [$id]);
        return $this->find($id);
    }
}
