<?php
declare(strict_types=1);
namespace App\Models;

final class Reserva extends CrudModel
{
    protected string $table = 'Reserva';
    protected string $key = 'ReservaID';
    public array $schema = ['PacienteID' => ['id'], 'ServicioID' => ['id'], 'AgendaID' => ['id'], 'ImporteReserva' => ['money']];
    public array $defaults = ['ImporteReserva' => '50.00'];

    public function create(array $data): array
    {
        $stmt = $this->db->prepare('DECLARE @id int; EXEC dbo.usp_CrearReserva ?, ?, ?, @id OUTPUT, ?; SELECT @id AS ReservaID;');
        $stmt->execute([$data['PacienteID'], $data['ServicioID'], $data['AgendaID'], $data['ImporteReserva']]);
        while ($stmt->columnCount() === 0 && $stmt->nextRowset()) {}
        $id = (int) $stmt->fetchColumn();
        $stmt->closeCursor();
        return $this->find($id);
    }

    public function update(int $id, array $data): array
    {
        $this->procedure('EXEC dbo.usp_ActualizarReserva ?, ?, ?, ?, ?', [$id, $data['PacienteID'], $data['ServicioID'], $data['AgendaID'], $data['ImporteReserva']]);
        return $this->find($id);
    }

    public function delete(int $id): array
    {
        $this->find($id);
        $this->procedure('EXEC dbo.usp_CancelarReserva ?', [$id]);
        return $this->find($id);
    }
}
