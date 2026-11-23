<?php
declare(strict_types=1);
namespace App\Controllers;
use App\Models\CrudModel;
use Core\Request;
use Core\Response;
use Core\Validator;

abstract class CrudController
{
    public function __construct(protected CrudModel $model) {}

    public function index(): never
    {
        Response::success($this->model->all(), 'Registros obtenidos.');
    }

    public function show(string $id): never
    {
        Response::success($this->model->find(Request::id($id)), 'Registro obtenido.');
    }

    public function store(): never
    {
        $data = Validator::validate(Request::body() + $this->model->defaults, $this->model->schema);
        $row = $this->model->create($data);
        Response::success($row, 'Registro creado.', 201);
    }

    public function update(string $id): never
    {
        $id = Request::id($id);
        $schema = $this->model->updateSchema ?? $this->model->schema;
        $data = Validator::validate(Request::body(), $schema);
        Response::success($this->model->update($id, $data), 'Registro actualizado.');
    }

    public function destroy(string $id): never
    {
        Response::success($this->model->delete(Request::id($id)), 'Baja, cancelación o anulación registrada.');
    }
}
