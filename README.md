# API MVC del consultorio de la Dra Iris Salazar

Proceso de Aprendizaje 4 · Programación Web Básica · NRC 3657 · Periodo 2026-20.
Diego Alberto Castillo Oviedo. Docente: LUIGGUI ENRIQUE YNGA BECERRA.

[Repositorio de entrega](https://github.com/dcastilloo/PA4-ProgramacionWeb-DiegoAlbertoCastilloOviedo)
· [Informe técnico](informe/3657_CastilloOviedo_DiegoAlberto_API_MVC.docx)
· [Evidencias de ejecución](evidencias/index.html).

Seis módulos REST sobre SQL Server: pacientes, servicios, agenda, reservas,
medios de pago y pagos. El proyecto continúa el modelo del PA3 y adapta la
arquitectura PHP del [proyecto base del docente](https://github.com/leyngab-isil/3657_PAGINA_WEB/tree/8255ded416ceea343bee9403f39f11fa7e8a4ac5).

## Requisitos

- SQL Server accesible y una cuenta con permiso para crear una base nueva.
- PHP 8.2 o superior, PDO, pdo_sqlsrv y mbstring; Composer.
- Para el asistente de Windows: PHP 8.2 TS x64, Microsoft ODBC Driver 17 o 18,
  PowerShell y acceso a Internet. Se probó con PHP 8.2.12 de XAMPP.
- Postman o Newman para la colección. Python 3 y sqlcmd para la batería adicional.

## Instalación en Windows

Abrir PowerShell en esta carpeta, la que contiene `composer.json`.

```powershell
.\scripts\preparar-local.ps1 -Php 'C:/xampp/php/php.exe'
```

El asistente descarga Composer 2.11.2 y PDO_SQLSRV 5.12.0, verifica sus SHA256,
instala el autoload y prepara `.env`. Guarda sus archivos en `.runtime/` sin
cambiar `php.ini` de XAMPP. El asistente está limitado a PHP 8.2 TS x64; para
otro runtime, instalar un controlador compatible siguiendo la documentación
de Microsoft y utilizar la instalación general indicada más abajo.

En SQL Server Management Studio, abrir `database/01_instalar.sql` y ejecutar
todo con F5. También puede usarse:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i database/01_instalar.sql
```

El SQL crea `PA4_3657_ConsultorioIris`, seis tablas, cinco FK, seis procedimientos,
restricciones, índices y población ficticia. Si la base ya existe, omite su
creación sin borrarla ni modificarla. Es una instalación completa basada en
PA3, no una migración sobre la base histórica del PA3. Una base con el mismo
nombre y esquema antiguo requiere revisión, no se actualiza automáticamente.

Revisar `.env`: servidor, base y autenticación. Los campos de usuario y
contraseña vacíos utilizan Windows con la identidad del proceso PHP. Para
autenticación SQL, introducir credenciales propias solamente en `.env`.
`DB_TRUST_CERTIFICATE=1` corresponde al certificado autofirmado de desarrollo
local. No publicar ese archivo ni usar esa opción como configuración de producción.

```powershell
.\scripts\php.ps1 -Argumentos @('scripts/check-db.php')
.\scripts\iniciar.ps1
```

La primera orden debe indicar la base y seis tablas. La segunda mantiene el
servidor en `http://127.0.0.1:8084`. Probar
[GET servicios](http://127.0.0.1:8084/api/servicios). `Ctrl+C` detiene el servidor.
El directorio público es exclusivamente `public/`, no la raíz del proyecto.

## Instalación general con PHP configurado

Cuando `php -m` ya muestre `pdo_sqlsrv` y `mbstring`:

```powershell
composer install --no-dev
Copy-Item .env.example .env
# Editar .env e instalar database/01_instalar.sql.
php scripts/check-db.php
composer run serve
```

No sobrescribir un `.env` existente. El servidor PHP integrado se usa para la
evaluación local. La entrega no incluye autenticación, despliegue público,
pasarela de cobros, frontend integrado, exposición ni video.

## Rutas y cuerpos JSON

Para cada recurso se ofrecen `GET /api/recurso`, `GET /api/recurso/{id}`,
`POST /api/recurso`, `PUT /api/recurso/{id}` y `DELETE /api/recurso/{id}`.
Son 30 operaciones. POST y PUT reciben `Content-Type: application/json`.

| Recurso | Cuerpo POST | Cuerpo PUT |
| --- | --- | --- |
| pacientes | NombreCompleto, Correo, Activo opcional | NombreCompleto, Correo, Activo |
| servicios | Nombre, Descripcion, Activo opcional | Nombre, Descripcion, Activo |
| medios-pago | Nombre, Activo opcional | Nombre, Activo |
| agenda | Inicio, Habilitada opcional | Inicio, Habilitada |
| reservas | PacienteID, ServicioID, AgendaID, ImporteReserva opcional | PacienteID, ServicioID, AgendaID, ImporteReserva |
| pagos | ReservaID, MedioPagoID, Importe, Referencia | MedioPagoID, Referencia |

Los ID son enteros JSON; `Activo` y `Habilitada`, booleanos JSON. Los importes
son cadenas con dos decimales, por ejemplo `"50.00"`; no se admiten números
JSON para importes. `Inicio` usa `YYYY-MM-DDTHH:00:00` en hora local de Lima,
sin sufijo de zona. Las fechas se comparan con la hora del SQL Server, que
debe corresponder a Lima. Las identidades, Fin, Estado, FechaRegistro,
FechaPago, Anulado y FechaAnulacion son controlados por el servidor.

Ejemplo de reserva:

```json
{"PacienteID":1,"ServicioID":1,"AgendaID":5,"ImporteReserva":"50.00"}
```

La agenda semilla corresponde a mañana y pasado mañana al instalar. Revisar
su disponibilidad antes de usar un ID: no se promete que AgendaID 5 siga libre.
Al vencer esos días, crear bloques futuros por API. No es necesario borrar
la base ni alterar el reloj del equipo para regenerar datos.

## Reglas del CRUD

Todos los listados y GET por ID incluyen registros inactivos, cancelados o
anulados para consultar el historial; no hay filtros implícitos ni paginación.
Los importes devueltos conservan dos decimales como cadenas; IDs y bits se
devuelven como números. DELETE responde 200 y el estado final del registro.
Una segunda baja devuelve 409; no produce un segundo cambio.

- Pacientes, servicios y medios: baja lógica. Se rechaza desactivar un paciente
  o servicio con reserva vigente, o un medio con pago vigente. PUT aplica la
  misma restricción si intenta desactivar. Puede reactivarse un catálogo por PUT.
- Agenda: Fin se calcula una hora después de Inicio. No se mueve ni se da de
  baja un bloque con reserva vigente. DELETE cambia Habilitada a 0.
- Reserva: se crea pendiente para paciente/servicio activos y un bloque futuro
  habilitado. PUT solo modifica reservas pendientes sin pago vigente; permite
  reprogramar. DELETE cancela una pendiente y conserva su historial.
- Pago: POST confirma la reserva en la misma transacción; un solo pago vigente
  por reserva e importe exacto. PUT solo corrige referencia/medio de un pago
  vigente de cita futura. DELETE anula administrativamente, conserva el pago
  con fecha de anulación y vuelve la reserva a pendiente en la misma transacción.
  Después puede registrarse un nuevo pago con referencia diferente. La anulación
  de un registro ficticio no procesa una devolución bancaria. No se modifican
  importe ni ReservaID y no se corrigen/anulan pagos de citas ya pasadas.

La ampliación de Pago agrega Anulado y FechaAnulacion y sustituye la unicidad
absoluta por un índice único filtrado sobre el pago vigente. Se conservan las
seis tablas y las cinco relaciones del PA3.

## Respuestas y errores

Éxito: `{"success":true,"message":"...","data":...}`.
Error: `{"success":false,"message":"..."}`.

200 consulta/actualización/baja, 201 creación, 400 entrada inválida, 404 recurso
o ruta inexistente, 405 método no permitido, 409 conflicto de unicidad/regla,
413 tamaño superior a 64 KiB, 415 contenido distinto de JSON y 500 fallo interno
sanitizado. Las FK de un cuerpo que no identifican una entidad válida para la
operación se tratan como conflicto 409. No se devuelven trazas ni credenciales.

## Postman y pruebas automatizadas

Importar `postman/PA4.postman_collection.json` y el entorno local. La URL base
es `http://127.0.0.1:8084`. Ejecutar la colección completa y en orden desde
Collection Runner. Genera nombres, referencias y fechas de prueba; guarda
automáticamente los ID para las siguientes solicitudes. No editar manualmente
los tokens numéricos `{{paciente_id}}` en los cuerpos. La colección tiene 38
solicitudes, cubre las 30 operaciones y realiza 78 aserciones.

La colección crea y luego da de baja registros ficticios, conservando su
historial. Se recomienda la base independiente de pruebas para ejecutarla.
Para reproducir esa base con Windows y sqlcmd:

```powershell
.\scripts\crear-base-pruebas.ps1
```

En dos terminales distintas, desde esta carpeta, iniciar sendos procesos PHP:

```powershell
$env:DB_DATABASE='PA4_3657_ConsultorioIris_Pruebas'
.\scripts\iniciar.ps1 -Puerto 8085
```

En la segunda, repetir con `-Puerto 8086`. Desde una tercera terminal:

```powershell
python tests/integracion.py --base http://127.0.0.1:8085 --base2 http://127.0.0.1:8086
npx --yes newman run postman/PA4.postman_collection.json --env-var base_url=http://127.0.0.1:8085
```

La batería estándar tiene 142 comprobaciones. Para agregar dos comprobaciones
del error 500, iniciar otro servidor aislado en 8087 con
`DB_DATABASE=PA4_BaseInexistente_ValidarError` y pasar
`--base-error http://127.0.0.1:8087` a Python. No crear esa base: su inexistencia
es la condición que provoca el error controlado. Las evidencias entregadas
registran 144/144 comprobaciones y 78/78 aserciones Newman correctas.

`evidencias/resultados.json` conserva cada solicitud/respuesta y las invariantes;
`newman.json` y `newman.txt` conservan la ejecución de la colección; `index.html`
permite leer el informe y las capturas muestran su contenido real. Son capturas
del informe de ejecución, no de la aplicación Postman. Las pruebas se ejecutaron
contra SQL Server real y dos procesos PHP para la concurrencia. Los registros
de prueba se cancelan/anulan/desactivan cuando corresponde y permanecen como
historial; no se promete restaurar conteos ni identidades.

## Estructura y autoría

`app/Models/` realiza consultas y llamadas a procedimientos; `app/Controllers/`
procesa entradas y respuestas; `routes/api.php` expone las rutas. `core/` reúne
router, validación, petición, respuesta y errores; `config/` carga el entorno
y crea PDO; `public/` es el punto de entrada. SQL y pruebas están separados.

Se tomó como referencia la organización del repositorio docente y el patrón
de respuesta uniforme y despacho de rutas, consultados en el commit indicado.
La configuración por entorno, validación estricta, modelos del consultorio,
reglas transaccionales adicionales, errores, instalación y pruebas corresponden
a esta adaptación. Se reutiliza el SQL del PA3 del mismo estudiante. El informe
documenta las diferencias y las fuentes con referencias APA.

El repositorio/ZIP excluye `.env`, `vendor/`, `.runtime/`, `.work/` y cachés.
Se conserva `composer.lock`. Instalar las dependencias antes de ejecutar.
