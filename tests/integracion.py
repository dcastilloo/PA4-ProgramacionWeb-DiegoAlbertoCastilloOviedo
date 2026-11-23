"""Pruebas HTTP reales sobre una base EXCLUSIVA de pruebas; solo biblioteca estándar.

Ejecutar después de instalar database/01_instalar.sql con un nombre de base distinto
y levantar dos procesos PHP que apunten a esa base (8085 y 8086 por defecto).
No limpia historial ni reinicia datos: cada ejecución usa registros ficticios únicos.
"""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import argparse
import json
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--base', default='http://127.0.0.1:8085')
parser.add_argument('--base2', default='http://127.0.0.1:8086')
parser.add_argument('--output', default='evidencias/resultados.json')
parser.add_argument('--server', default='localhost')
parser.add_argument('--database', default='PA4_3657_ConsultorioIris_Pruebas')
parser.add_argument('--base-error', default='', help='Servidor aislado con una base inexistente, para comprobar HTTP 500.')
args = parser.parse_args()
if not args.database.endswith('_Pruebas') or not args.database.replace('_', '').isalnum():
    raise SystemExit('Use una base cuyo nombre termine en _Pruebas.')
events = []
token = uuid.uuid4().hex[:10]

def sql(query):
    p = subprocess.run(['sqlcmd', '-S', args.server, '-E', '-b', '-h', '-1', '-W', '-d', args.database,
                        '-Q', 'SET NOCOUNT ON; ' + query], capture_output=True, text=True, check=True)
    return p.stdout.strip()

# La precondición evita ejecutar por error la batería contra la base de entrega.
actual = sql('SELECT DB_NAME();')
assert actual == args.database

def call(label, method, path, body=None, expected=200, raw=None, content_type='application/json', base=None):
    payload = raw if raw is not None else (json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None)
    start = time.monotonic()
    req = Request((base or args.base) + path, data=payload, method=method,
                  headers={'Content-Type': content_type} if payload is not None else {})
    try:
        response = urlopen(req, timeout=25)
    except HTTPError as error:
        response = error
    status = response.code
    response_text = response.read().decode('utf-8')
    try:
        result = json.loads(response_text)
    except json.JSONDecodeError:
        result = {'respuesta_no_json': response_text}
    event = {'caso': label, 'metodo': method, 'ruta': path, 'solicitud': body if raw is None else raw.decode('utf-8', errors='replace'),
             'estado_esperado': expected, 'estado_recibido': status, 'respuesta': result,
             'duracion_ms': round((time.monotonic() - start) * 1000, 2), 'correcto': status == expected}
    events.append(event)
    if status != expected:
        raise AssertionError(f'{label}: esperado {expected}, recibido {status}: {result}')
    assert isinstance(result.get('success'), bool), event
    assert result['success'] == (status < 400), event
    assert 'sqlsrv:' not in response_text.lower() and 'stack trace' not in response_text.lower(), event
    return result.get('data')

def verify(label, condition):
    events.append({'caso': label, 'correcto': bool(condition), 'tipo': 'invariante'})
    assert condition, label

def agenda(offset):
    return (datetime.now() + timedelta(days=14 + offset)).replace(hour=9, minute=0, second=0, microsecond=0).isoformat()

def run():
    resources = [('pacientes', 'PacienteID'), ('servicios', 'ServicioID'), ('agenda', 'AgendaID'),
                 ('medios-pago', 'MedioPagoID'), ('reservas', 'ReservaID'), ('pagos', 'PagoID')]
    # Listado, detalle e inexistente para las seis tablas.
    for resource, key in resources:
        data = call(f'{resource}: listar', 'GET', f'/api/{resource}')
        verify(f'{resource}: lista JSON', isinstance(data, list) and len(data) > 0)
        row = call(f'{resource}: consultar ID', 'GET', f'/api/{resource}/{data[0][key]}')
        verify(f'{resource}: corresponde el ID', row[key] == data[0][key])
        call(f'{resource}: ID inexistente', 'GET', f'/api/{resource}/2147483647', expected=404)

    patient = {'NombreCompleto': f'Paciente Prueba {token}', 'Correo': f'{token}@example.com'}
    p = call('pacientes: crear', 'POST', '/api/pacientes', patient, 201)['PacienteID']
    pu = {**patient, 'NombreCompleto': f'Paciente Editado {token}', 'Activo': True}
    edited = call('pacientes: actualizar', 'PUT', f'/api/pacientes/{p}', pu)
    verify('pacientes: cambios persistidos', edited['NombreCompleto'] == pu['NombreCompleto'])
    call('pacientes: correo duplicado', 'POST', '/api/pacientes', patient, 409)
    call('pacientes: correo inválido', 'POST', '/api/pacientes', {**patient, 'Correo': 'invalido'}, 400)
    call('pacientes: nombre largo', 'POST', '/api/pacientes', {**patient, 'NombreCompleto': 'A' * 81}, 400)
    call('pacientes: longitud Unicode SQL', 'POST', '/api/pacientes', {**patient, 'NombreCompleto': '\U0001F600' * 41}, 400)
    call('pacientes: falta obligatorio', 'POST', '/api/pacientes', {'Correo': 'otro@example.com'}, 400)
    call('pacientes: tipo booleano', 'PUT', f'/api/pacientes/{p}', {**pu, 'Activo': 'true'}, 400)
    call('pacientes: identidad no editable', 'POST', '/api/pacientes', {**patient, 'PacienteID': 99}, 400)
    call('pacientes: PUT inexistente', 'PUT', '/api/pacientes/2147483647', pu, 404)
    call('pacientes: DELETE inexistente', 'DELETE', '/api/pacientes/2147483647', expected=404)

    service = {'Nombre': f'Servicio {token}', 'Descripcion': 'Evaluación ficticia con acentos.'}
    s = call('servicios: crear', 'POST', '/api/servicios', service, 201)['ServicioID']
    su = {**service, 'Descripcion': 'Descripción actualizada.', 'Activo': True}
    edited = call('servicios: actualizar', 'PUT', f'/api/servicios/{s}', su)
    verify('servicios: cambios persistidos', edited['Descripcion'] == su['Descripcion'])
    call('servicios: nombre duplicado', 'POST', '/api/servicios', service, 409)
    call('servicios: descripción vacía', 'POST', '/api/servicios', {**service, 'Descripcion': ' '}, 400)

    medium = {'Nombre': f'Medio prueba {token}'}
    m = call('medios-pago: crear', 'POST', '/api/medios-pago', medium, 201)['MedioPagoID']
    mu = {'Nombre': f'Medio editado {token}', 'Activo': True}
    call('medios-pago: actualizar', 'PUT', f'/api/medios-pago/{m}', mu)
    call('medios-pago: duplicado', 'POST', '/api/medios-pago', mu, 409)

    # Fechas únicas por ejecución, alejadas de los datos semilla.
    day = int(token[:4], 16) % 15000 + 30
    a = call('agenda: crear', 'POST', '/api/agenda', {'Inicio': agenda(day)}, 201)['AgendaID']
    au = {'Inicio': agenda(day + 1), 'Habilitada': True}
    call('agenda: actualizar', 'PUT', f'/api/agenda/{a}', au)
    call('agenda: inicio duplicado', 'POST', '/api/agenda', au, 409)
    call('agenda: fecha pasada', 'POST', '/api/agenda', {'Inicio': '2000-01-01T09:00:00'}, 409)
    call('agenda: fecha inexistente', 'POST', '/api/agenda', {'Inicio': '2027-02-30T09:00:00'}, 400)
    call('agenda: año fuera de SQL Server', 'POST', '/api/agenda', {'Inicio': '0000-01-01T09:00:00'}, 400)
    call('agenda: Fin fuera del rango SQL', 'POST', '/api/agenda', {'Inicio': '9999-12-31T23:00:00'}, 400)
    call('agenda: minuto no exacto', 'POST', '/api/agenda', {'Inicio': '2027-03-01T09:15:00'}, 400)
    call('agenda: Fin calculado', 'POST', '/api/agenda', {'Inicio': agenda(day + 5), 'Fin': agenda(day + 6)}, 400)
    a2 = call('agenda: bloque alternativo', 'POST', '/api/agenda', {'Inicio': agenda(day + 2)}, 201)['AgendaID']
    rbody = {'PacienteID': p, 'ServicioID': s, 'AgendaID': a, 'ImporteReserva': '50.00'}
    r = call('reservas: crear', 'POST', '/api/reservas', rbody, 201)['ReservaID']
    call('reservas: doble reserva', 'POST', '/api/reservas', rbody, 409)
    call('reservas: paciente inexistente', 'POST', '/api/reservas', {**rbody, 'PacienteID': 2147483647}, 409)
    call('reservas: servicio inexistente', 'POST', '/api/reservas', {**rbody, 'ServicioID': 2147483647}, 409)
    call('reservas: agenda inexistente', 'POST', '/api/reservas', {**rbody, 'AgendaID': 2147483647}, 409)
    call('reservas: importe negativo', 'POST', '/api/reservas', {**rbody, 'ImporteReserva': '-1.00'}, 400)
    call('reservas: importe numérico no contractual', 'POST', '/api/reservas', {**rbody, 'ImporteReserva': 50.0}, 400)
    call('reservas: identidad como texto', 'POST', '/api/reservas', {**rbody, 'PacienteID': str(p)}, 400)
    call('reservas: Estado no editable', 'PUT', f'/api/reservas/{r}', {**rbody, 'Estado': 'CONFIRMADA'}, 400)
    call('agenda: no mover ocupada', 'PUT', f'/api/agenda/{a}', {'Inicio': agenda(day + 3), 'Habilitada': True}, 409)
    call('agenda: no deshabilitar ocupada', 'DELETE', f'/api/agenda/{a}', expected=409)
    call('pacientes: no desactivar con reserva', 'DELETE', f'/api/pacientes/{p}', expected=409)
    call('pacientes: PUT no omite restricción de baja', 'PUT', f'/api/pacientes/{p}', {**pu, 'Activo': False}, 409)
    call('servicios: no desactivar con reserva', 'DELETE', f'/api/servicios/{s}', expected=409)
    ru = {**rbody, 'AgendaID': a2}
    call('reservas: actualizar y reprogramar', 'PUT', f'/api/reservas/{r}', ru)
    verify('reservas: reprogramación persistida', int(call('reservas: verificar agenda', 'GET', f'/api/reservas/{r}')['AgendaID']) == a2)
    call('agenda: DELETE bloque liberado', 'DELETE', f'/api/agenda/{a}')
    call('agenda: repetir DELETE', 'DELETE', f'/api/agenda/{a}', expected=409)
    call('reservas: agenda deshabilitada', 'POST', '/api/reservas', rbody, 409)
    paybody = {'ReservaID': r, 'MedioPagoID': m, 'Importe': '50.00', 'Referencia': f'PRUEBA-{token}'}
    call('pagos: importe distinto', 'POST', '/api/pagos', {**paybody, 'Importe': '49.99'}, 409)
    verify('pagos: fallo no confirma reserva', call('reservas: tras pago inválido', 'GET', f'/api/reservas/{r}')['Estado'] == 'PENDIENTE')
    pay = call('pagos: crear', 'POST', '/api/pagos', paybody, 201)['PagoID']
    verify('pagos: confirma reserva', call('reservas: tras pago correcto', 'GET', f'/api/reservas/{r}')['Estado'] == 'CONFIRMADA')
    call('pagos: segundo pago vigente', 'POST', '/api/pagos', {**paybody, 'Referencia': f'OTRO-{token}'}, 409)
    call('reservas: no editar confirmada', 'PUT', f'/api/reservas/{r}', ru, 409)
    call('reservas: no cancelar pagada', 'DELETE', f'/api/reservas/{r}', expected=409)
    call('medios-pago: no desactivar con pago', 'DELETE', f'/api/medios-pago/{m}', expected=409)
    call('pagos: no alterar importe', 'PUT', f'/api/pagos/{pay}', {'MedioPagoID': m, 'Referencia': f'EDIT-{token}', 'Importe': '60.00'}, 400)
    corrected = call('pagos: actualizar referencia y medio', 'PUT', f'/api/pagos/{pay}', {'MedioPagoID': m, 'Referencia': f'EDIT-{token}'})
    verify('pagos: referencia corregida', corrected['Referencia'] == f'EDIT-{token}' and corrected['Importe'] == '50.00')
    call('pagos: medio inexistente', 'PUT', f'/api/pagos/{pay}', {'MedioPagoID': 255, 'Referencia': f'EDIT-{token}'}, 409)
    annulled = call('pagos: DELETE anula y conserva', 'DELETE', f'/api/pagos/{pay}')
    verify('pagos: anulación con fecha', int(annulled['Anulado']) == 1 and annulled['FechaAnulacion'] is not None)
    verify('pagos: reserva vuelve a pendiente', call('reservas: tras anulación', 'GET', f'/api/reservas/{r}')['Estado'] == 'PENDIENTE')
    call('pagos: repetir DELETE', 'DELETE', f'/api/pagos/{pay}', expected=409)
    call('pagos: no editar anulado', 'PUT', f'/api/pagos/{pay}', {'MedioPagoID': m, 'Referencia': f'EDIT2-{token}'}, 409)
    call('pagos: referencia histórica única', 'POST', '/api/pagos', {**paybody, 'Referencia': f'EDIT-{token}'}, 409)
    verify('pagos: duplicado no confirma reserva', call('reservas: tras referencia duplicada', 'GET', f'/api/reservas/{r}')['Estado'] == 'PENDIENTE')
    newpay = call('pagos: registrar reemplazo tras anulación', 'POST', '/api/pagos', {**paybody, 'Referencia': f'NUEVO-{token}'}, 201)['PagoID']
    call('pagos: anular reemplazo', 'DELETE', f'/api/pagos/{newpay}')
    call('reservas: DELETE cancela pendiente', 'DELETE', f'/api/reservas/{r}')
    call('reservas: repetir DELETE', 'DELETE', f'/api/reservas/{r}', expected=409)
    call('reservas: no editar cancelada', 'PUT', f'/api/reservas/{r}', ru, 409)
    call('pacientes: DELETE baja lógica', 'DELETE', f'/api/pacientes/{p}')
    verify('pacientes: historial visible tras baja', int(call('pacientes: consultar baja', 'GET', f'/api/pacientes/{p}')['Activo']) == 0)
    call('pacientes: repetir DELETE', 'DELETE', f'/api/pacientes/{p}', expected=409)
    call('reservas: paciente inactivo', 'POST', '/api/reservas', ru, 409)
    call('servicios: DELETE baja lógica', 'DELETE', f'/api/servicios/{s}')
    call('medios-pago: DELETE baja lógica', 'DELETE', f'/api/medios-pago/{m}')
    call('agenda: DELETE después de cancelación', 'DELETE', f'/api/agenda/{a2}')

    for value in ['0', '-1', 'abc', '2147483648', '1%27%20OR%201=1']:
        call(f'ID inválido {value}', 'GET', f'/api/pacientes/{value}', expected=400)
    call('JSON roto', 'POST', '/api/pacientes', raw=b'{', expected=400)
    call('JSON array', 'POST', '/api/pacientes', raw=b'[]', expected=400)
    call('JSON null', 'POST', '/api/pacientes', raw=b'null', expected=400)
    call('Tipo de contenido incorrecto', 'POST', '/api/pacientes', raw=b'{}', content_type='text/plain', expected=415)
    call('Tamaño excesivo', 'POST', '/api/pacientes', raw=b'{"x":"' + b'x' * 66000 + b'"}', expected=413)
    call('Método no permitido', 'PATCH', '/api/pacientes/1', {}, 405)
    call('Ruta inexistente', 'GET', '/api/no-existe', expected=404)
    call('Entorno no expuesto', 'GET', '/.env', expected=404)
    call('Código no expuesto', 'GET', '/config/Database.php', expected=404)
    injection = "SQL de prueba '; DROP TABLE Paciente;--"
    injected = call('Texto SQL se trata como dato', 'POST', '/api/pacientes', {'NombreCompleto': injection, 'Correo': f'inj{token}@example.com'}, 201)
    verify('Texto SQL conservado sin ejecutar', injected['NombreCompleto'] == injection)
    call('Eliminar paciente de prueba de inyección', 'DELETE', f"/api/pacientes/{injected['PacienteID']}")

    # Dos servidores PHP para que Windows use dos conexiones HTTP realmente distintas.
    ca = call('Concurrencia: preparar agenda', 'POST', '/api/agenda', {'Inicio': agenda(day + 10)}, 201)['AgendaID']
    concurrent_body = {'PacienteID': 1, 'ServicioID': 1, 'AgendaID': ca, 'ImporteReserva': '50.00'}
    def attempt(base):
        req = Request(base + '/api/reservas', data=json.dumps(concurrent_body).encode(), method='POST', headers={'Content-Type': 'application/json'})
        try: res = urlopen(req, timeout=20)
        except HTTPError as err: res = err
        return res.code, json.loads(res.read().decode())
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = list(pool.map(attempt, [args.base, args.base2]))
    verify('Concurrencia: exactamente un 201 y un 409', sorted(x[0] for x in outcomes) == [201, 409])
    events.append({'caso': 'Concurrencia: solicitudes y respuestas', 'solicitud': concurrent_body, 'respuestas': outcomes, 'correcto': True})
    winner = next(data['data']['ReservaID'] for status, data in outcomes if status == 201)
    call('Concurrencia: cancelar reserva temporal', 'DELETE', f'/api/reservas/{winner}')
    call('Concurrencia: deshabilitar bloque temporal', 'DELETE', f'/api/agenda/{ca}')
    verify('SQL: sin doble reserva vigente', sql("SELECT COUNT(*) FROM (SELECT AgendaID FROM dbo.Reserva WHERE Estado <> 'CANCELADA' GROUP BY AgendaID HAVING COUNT(*) > 1) d;") == '0')
    verify('SQL: confirmaciones consistentes con pago vigente', sql("SELECT COUNT(*) FROM dbo.Reserva r WHERE (r.Estado = 'CONFIRMADA' AND NOT EXISTS (SELECT 1 FROM dbo.Pago p WHERE p.ReservaID=r.ReservaID AND p.Anulado=0)) OR (r.Estado <> 'CONFIRMADA' AND EXISTS (SELECT 1 FROM dbo.Pago p WHERE p.ReservaID=r.ReservaID AND p.Anulado=0));") == '0')
    verify('SQL: seis tablas conservadas', sql('SELECT COUNT(*) FROM sys.tables;') == '6')
    sql('DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;')
    events.append({'caso': 'DBCC CHECKCONSTRAINTS sin errores', 'correcto': True})
    if args.base_error:
        call('Error interno: conexión inválida devuelve JSON 500', 'GET', '/api/pacientes', expected=500, base=args.base_error)
        error_event = events[-1]
        verify('Error interno: no revela base, driver ni credenciales', all(value not in json.dumps(error_event['respuesta']).lower() for value in ['password', 'sqlstate', 'baseinexistente', 'pdoexception', 'sqlsrv', 'stack trace']))

try:
    run()
finally:
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    report = {'fecha': datetime.now().isoformat(timespec='seconds'), 'base_http': args.base, 'base_datos': args.database,
              'total': len(events), 'correctos': sum(e['correcto'] for e in events),
              'fallos': sum(not e['correcto'] for e in events), 'casos': events}
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k != 'casos'}, ensure_ascii=False))
