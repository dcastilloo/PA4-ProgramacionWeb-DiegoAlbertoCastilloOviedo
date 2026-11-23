/*
  PROCESO DE APRENDIZAJE 4 - Programacion Web Basica
  Diego Alberto Castillo Oviedo | NRC 3657 | Periodo 2026-20
  Docente: LUIGGUI ENRIQUE YNGA BECERRA
  
  Crea una base nueva; si ya existe, no la elimina ni repuebla.
  Los pacientes, fechas, referencias e importes son datos ficticios de prueba.
  La agenda corresponde solo a la Dra. Iris Salazar. No procesa cobros reales.
*/
USE master;
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF DB_ID(N'PA4_3657_ConsultorioIris') IS NOT NULL
BEGIN
    PRINT N'La base PA4_3657_ConsultorioIris ya existe. No se modificara. Use el archivo de pruebas o una instancia nueva.';
    SET NOEXEC ON;
END;
GO

-- 1. Creacion de la base de datos.
CREATE DATABASE PA4_3657_ConsultorioIris;
GO
USE PA4_3657_ConsultorioIris;
GO

-- 2. Tablas, claves y restricciones.
CREATE TABLE dbo.Paciente (
    PacienteID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Paciente PRIMARY KEY,
    NombreCompleto nvarchar(80) NOT NULL,
    Correo nvarchar(120) NOT NULL,
    Activo bit NOT NULL CONSTRAINT DF_Paciente_Activo DEFAULT (1),
    CONSTRAINT UQ_Paciente_Correo UNIQUE (Correo),
    CONSTRAINT CK_Paciente_Nombre CHECK (LEN(LTRIM(RTRIM(NombreCompleto))) >= 3),
    -- Comprobacion basica de estructura; no verifica la existencia del buzon.
    CONSTRAINT CK_Paciente_Correo CHECK (Correo LIKE N'%_@_%._%' AND Correo NOT LIKE N'% %')
);

CREATE TABLE dbo.Servicio (
    ServicioID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Servicio PRIMARY KEY,
    Nombre nvarchar(80) NOT NULL,
    Descripcion nvarchar(250) NOT NULL,
    Activo bit NOT NULL CONSTRAINT DF_Servicio_Activo DEFAULT (1),
    CONSTRAINT UQ_Servicio_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Servicio_Nombre CHECK (LEN(LTRIM(RTRIM(Nombre))) >= 3),
    CONSTRAINT CK_Servicio_Descripcion CHECK (LEN(LTRIM(RTRIM(Descripcion))) > 0)
);

CREATE TABLE dbo.Agenda (
    AgendaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Agenda PRIMARY KEY,
    Inicio datetime2(0) NOT NULL,
    Fin AS DATEADD(hour, 1, Inicio) PERSISTED,
    Habilitada bit NOT NULL CONSTRAINT DF_Agenda_Habilitada DEFAULT (1),
    CONSTRAINT UQ_Agenda_Inicio UNIQUE (Inicio),
    -- Bloques de evaluacion de una hora; no representan duracion de tratamientos.
    CONSTRAINT CK_Agenda_HoraExacta CHECK (DATEPART(minute, Inicio) = 0 AND DATEPART(second, Inicio) = 0)
);

CREATE TABLE dbo.MedioPago (
    MedioPagoID tinyint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MedioPago PRIMARY KEY,
    Nombre nvarchar(50) NOT NULL,
    Activo bit NOT NULL CONSTRAINT DF_MedioPago_Activo DEFAULT (1),
    CONSTRAINT UQ_MedioPago_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_MedioPago_Nombre CHECK (LEN(LTRIM(RTRIM(Nombre))) >= 3)
);

CREATE TABLE dbo.Reserva (
    ReservaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Reserva PRIMARY KEY,
    PacienteID int NOT NULL,
    ServicioID int NOT NULL,
    AgendaID int NOT NULL,
    FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Reserva_Fecha DEFAULT (SYSDATETIME()),
    Estado varchar(12) NOT NULL CONSTRAINT DF_Reserva_Estado DEFAULT ('PENDIENTE'),
    ImporteReserva decimal(10,2) NOT NULL,
    CONSTRAINT FK_Reserva_Paciente FOREIGN KEY (PacienteID) REFERENCES dbo.Paciente(PacienteID),
    CONSTRAINT FK_Reserva_Servicio FOREIGN KEY (ServicioID) REFERENCES dbo.Servicio(ServicioID),
    CONSTRAINT FK_Reserva_Agenda FOREIGN KEY (AgendaID) REFERENCES dbo.Agenda(AgendaID),
    CONSTRAINT CK_Reserva_Estado CHECK (Estado IN ('PENDIENTE', 'CONFIRMADA', 'CANCELADA')),
    CONSTRAINT CK_Reserva_Importe CHECK (ImporteReserva > 0)
);

CREATE TABLE dbo.Pago (
    PagoID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pago PRIMARY KEY,
    ReservaID int NOT NULL,
    MedioPagoID tinyint NOT NULL,
    FechaPago datetime2(0) NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (SYSDATETIME()),
    Importe decimal(10,2) NOT NULL,
    Referencia nvarchar(40) NOT NULL,
    CONSTRAINT FK_Pago_Reserva FOREIGN KEY (ReservaID) REFERENCES dbo.Reserva(ReservaID),
    CONSTRAINT FK_Pago_MedioPago FOREIGN KEY (MedioPagoID) REFERENCES dbo.MedioPago(MedioPagoID),
    Anulado bit NOT NULL CONSTRAINT DF_Pago_Anulado DEFAULT (0),
    FechaAnulacion datetime2(0) NULL,
    CONSTRAINT CK_Pago_Anulacion CHECK ((Anulado = 0 AND FechaAnulacion IS NULL) OR (Anulado = 1 AND FechaAnulacion IS NOT NULL)),
    CONSTRAINT UQ_Pago_Referencia UNIQUE (Referencia),
    CONSTRAINT CK_Pago_Importe CHECK (Importe > 0),
    CONSTRAINT CK_Pago_Referencia CHECK (LEN(LTRIM(RTRIM(Referencia))) >= 4)
);
GO

-- PA4 conserva el historial de pagos anulados y admite un solo pago vigente.
CREATE UNIQUE INDEX UX_Pago_ReservaVigente ON dbo.Pago(ReservaID) WHERE Anulado = 0;
GO

-- 3. Indices vinculados a consultas e integridad.
-- Una cancelacion conserva historial y libera el bloque para otra reserva.
CREATE UNIQUE INDEX UX_Reserva_AgendaVigente
    ON dbo.Reserva(AgendaID) WHERE Estado <> 'CANCELADA';
CREATE INDEX IX_Reserva_Paciente_Fecha
    ON dbo.Reserva(PacienteID, FechaRegistro DESC) INCLUDE (ServicioID, AgendaID, Estado);
CREATE INDEX IX_Reserva_Servicio ON dbo.Reserva(ServicioID) INCLUDE (Estado);
CREATE INDEX IX_Pago_Medio_Fecha ON dbo.Pago(MedioPagoID, FechaPago) INCLUDE (Importe);
GO

-- 4. Procedimientos almacenados. Usarlos para las operaciones de negocio.
CREATE PROCEDURE dbo.usp_CrearReserva
    @PacienteID int,
    @ServicioID int,
    @AgendaID int,
    @ReservaID int OUTPUT,
    @ImporteReserva decimal(10,2) = 50.00
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @ReservaID = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @ImporteReserva IS NULL OR @ImporteReserva <= 0
            THROW 51001, N'El importe de reserva debe ser positivo.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Paciente WITH (HOLDLOCK) WHERE PacienteID = @PacienteID AND Activo = 1)
            THROW 51002, N'El paciente no existe o esta inactivo.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Servicio WITH (HOLDLOCK) WHERE ServicioID = @ServicioID AND Activo = 1)
            THROW 51003, N'El servicio no existe o esta inactivo.', 1;

        -- Serializa solicitudes sobre el mismo bloque de agenda.
        DECLARE @Inicio datetime2(0), @Habilitada bit;
        SELECT @Inicio = Inicio, @Habilitada = Habilitada
        FROM dbo.Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaID = @AgendaID;
        IF @Inicio IS NULL OR @Habilitada = 0
            THROW 51004, N'El bloque no existe o esta deshabilitado.', 1;
        IF @Inicio <= SYSDATETIME()
            THROW 51005, N'La cita debe tener una fecha y hora futuras.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Reserva WHERE AgendaID = @AgendaID AND Estado <> 'CANCELADA')
            THROW 51006, N'El bloque ya tiene una reserva vigente.', 1;

        INSERT dbo.Reserva(PacienteID, ServicioID, AgendaID, ImporteReserva)
        VALUES (@PacienteID, @ServicioID, @AgendaID, @ImporteReserva);
        SET @ReservaID = CONVERT(int, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @ReservaID = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_RegistrarPago
    @ReservaID int,
    @MedioPagoID tinyint,
    @Importe decimal(10,2),
    @Referencia nvarchar(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Estado varchar(12), @Esperado decimal(10,2);
        SELECT @Estado = Estado, @Esperado = ImporteReserva
        FROM dbo.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE ReservaID = @ReservaID;
        IF @Estado IS NULL OR @Estado <> 'PENDIENTE'
            THROW 51010, N'Solo puede pagarse una reserva pendiente.', 1;
        IF @Importe IS NULL OR @Importe <> @Esperado
            THROW 51011, N'El pago debe coincidir con el importe de la reserva.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.MedioPago WITH (HOLDLOCK) WHERE MedioPagoID = @MedioPagoID AND Activo = 1)
            THROW 51012, N'El medio de pago no existe o esta inactivo.', 1;
        IF @Referencia IS NULL OR LEN(LTRIM(RTRIM(@Referencia))) < 4
            THROW 51013, N'La referencia de pago no es valida.', 1;

        INSERT dbo.Pago(ReservaID, MedioPagoID, Importe, Referencia)
        VALUES (@ReservaID, @MedioPagoID, @Importe, LTRIM(RTRIM(@Referencia)));
        UPDATE dbo.Reserva SET Estado = 'CONFIRMADA' WHERE ReservaID = @ReservaID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_CancelarReserva
    @ReservaID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Estado varchar(12);
        SELECT @Estado = Estado FROM dbo.Reserva WITH (UPDLOCK, HOLDLOCK)
        WHERE ReservaID = @ReservaID;
        IF @Estado IS NULL OR @Estado <> 'PENDIENTE'
            THROW 51020, N'Solo puede cancelarse una reserva pendiente.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Pago WHERE ReservaID = @ReservaID AND Anulado = 0)
            THROW 51021, N'No puede cancelarse una reserva con pago registrado.', 1;
        UPDATE dbo.Reserva SET Estado = 'CANCELADA' WHERE ReservaID = @ReservaID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- PA4: reprogramacion solo de reservas pendientes sin pago vigente.
CREATE PROCEDURE dbo.usp_ActualizarReserva
    @ReservaID int, @PacienteID int, @ServicioID int, @AgendaID int, @ImporteReserva decimal(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Estado varchar(12);
        SELECT @Estado = Estado FROM dbo.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE ReservaID = @ReservaID;
        IF @Estado IS NULL THROW 51031, N'La reserva no existe.', 1;
        IF @Estado <> 'PENDIENTE' OR EXISTS (SELECT 1 FROM dbo.Pago WHERE ReservaID = @ReservaID AND Anulado = 0)
            THROW 51030, N'Solo puede modificarse una reserva pendiente sin pago vigente.', 1;
        IF @ImporteReserva IS NULL OR @ImporteReserva <= 0 THROW 51001, N'Importe invalido.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Paciente WITH (HOLDLOCK) WHERE PacienteID = @PacienteID AND Activo = 1)
            THROW 51002, N'Paciente inexistente o inactivo.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Servicio WITH (HOLDLOCK) WHERE ServicioID = @ServicioID AND Activo = 1)
            THROW 51003, N'Servicio inexistente o inactivo.', 1;
        DECLARE @Inicio datetime2(0), @Habilitada bit;
        SELECT @Inicio = Inicio, @Habilitada = Habilitada FROM dbo.Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaID = @AgendaID;
        IF @Inicio IS NULL OR @Habilitada = 0 THROW 51004, N'Agenda inexistente o deshabilitada.', 1;
        IF @Inicio <= SYSDATETIME() THROW 51005, N'La cita debe estar en el futuro.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Reserva WHERE AgendaID = @AgendaID AND Estado <> 'CANCELADA' AND ReservaID <> @ReservaID)
            THROW 51006, N'El bloque ya tiene una reserva vigente.', 1;
        UPDATE dbo.Reserva SET PacienteID = @PacienteID, ServicioID = @ServicioID,
            AgendaID = @AgendaID, ImporteReserva = @ImporteReserva WHERE ReservaID = @ReservaID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Corregir solo medio y referencia. No cambia importe ni reserva del pago.
CREATE PROCEDURE dbo.usp_ActualizarPago
    @PagoID int, @MedioPagoID tinyint, @Referencia nvarchar(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ReservaID int, @Estado varchar(12), @Anulado bit, @AgendaID int, @Inicio datetime2(0);
        SELECT @ReservaID = ReservaID FROM dbo.Pago WHERE PagoID = @PagoID;
        IF @ReservaID IS NULL THROW 51040, N'El pago no existe.', 1;
        SELECT @Estado = Estado, @AgendaID = AgendaID FROM dbo.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE ReservaID = @ReservaID;
        SELECT @Anulado = Anulado FROM dbo.Pago WITH (UPDLOCK, HOLDLOCK) WHERE PagoID = @PagoID;
        IF @Anulado = 1 OR @Estado <> 'CONFIRMADA' THROW 51041, N'Pago no vigente.', 1;
        SELECT @Inicio = Inicio FROM dbo.Agenda WITH (HOLDLOCK) WHERE AgendaID = @AgendaID;
        IF @Inicio <= SYSDATETIME() THROW 51042, N'La cita ya no es futura.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.MedioPago WITH (HOLDLOCK) WHERE MedioPagoID = @MedioPagoID AND Activo = 1)
            THROW 51012, N'Medio inexistente o inactivo.', 1;
        IF @Referencia IS NULL OR LEN(LTRIM(RTRIM(@Referencia))) < 4 THROW 51013, N'Referencia invalida.', 1;
        UPDATE dbo.Pago SET MedioPagoID = @MedioPagoID, Referencia = LTRIM(RTRIM(@Referencia)) WHERE PagoID = @PagoID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Anulacion administrativa del registro ficticio, no una devolucion bancaria.
CREATE PROCEDURE dbo.usp_AnularPago @PagoID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ReservaID int, @Estado varchar(12), @Anulado bit, @AgendaID int, @Inicio datetime2(0);
        SELECT @ReservaID = ReservaID FROM dbo.Pago WHERE PagoID = @PagoID;
        IF @ReservaID IS NULL THROW 51040, N'El pago no existe.', 1;
        SELECT @Estado = Estado, @AgendaID = AgendaID FROM dbo.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE ReservaID = @ReservaID;
        SELECT @Anulado = Anulado FROM dbo.Pago WITH (UPDLOCK, HOLDLOCK) WHERE PagoID = @PagoID;
        IF @Anulado = 1 OR @Estado <> 'CONFIRMADA' THROW 51041, N'Pago no vigente.', 1;
        SELECT @Inicio = Inicio FROM dbo.Agenda WITH (HOLDLOCK) WHERE AgendaID = @AgendaID;
        IF @Inicio <= SYSDATETIME() THROW 51042, N'La cita ya no es futura.', 1;
        UPDATE dbo.Pago SET Anulado = 1, FechaAnulacion = SYSDATETIME() WHERE PagoID = @PagoID;
        UPDATE dbo.Reserva SET Estado = 'PENDIENTE' WHERE ReservaID = @ReservaID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- 5. Datos ficticios. Ninguna tabla supera diez registros.
INSERT dbo.Paciente(NombreCompleto, Correo, Activo) VALUES
(N'Ana Torres Ejemplo', N'ana.torres@example.com', 1),
(N'Luis Ramos Ejemplo', N'luis.ramos@example.com', 1),
(N'Maria Vega Ejemplo', N'maria.vega@example.com', 1),
(N'Pedro Leon Ejemplo', N'pedro.leon@example.com', 1),
(N'Lucia Rios Ejemplo', N'lucia.rios@example.com', 0);

INSERT dbo.Servicio(Nombre, Descripcion) VALUES
(N'Estética dental', N'Procedimientos orientados a mejorar la apariencia de la sonrisa.'),
(N'Ortodoncia', N'Corrección progresiva de la posición dental y la mordida.'),
(N'Endodoncia', N'Tratamiento para conservar dientes con daño interno.'),
(N'Rehabilitación oral', N'Recuperación de la función y forma de las piezas dentales.'),
(N'Implantología', N'Alternativas para reemplazar piezas dentales perdidas.'),
(N'Cirugía maxilofacial', N'Evaluación y procedimientos quirúrgicos según el diagnóstico.');

INSERT dbo.MedioPago(Nombre) VALUES
(N'Tarjeta de crédito o débito'), (N'Billetera digital');

-- Agenda relativa al dia de ejecucion del servidor, con bloques de una hora.
DECLARE @Manana datetime2(0) = CONVERT(date, DATEADD(day, 1, SYSDATETIME()));
INSERT dbo.Agenda(Inicio, Habilitada) VALUES
(DATEADD(hour, 9, @Manana), 1),
(DATEADD(hour, 10, @Manana), 1),
(DATEADD(hour, 11, @Manana), 1),
(DATEADD(hour, 15, @Manana), 1),
(DATEADD(hour, 16, @Manana), 1),
(DATEADD(hour, 17, @Manana), 0),
(DATEADD(hour, 9, DATEADD(day, 1, @Manana)), 1),
(DATEADD(hour, 10, DATEADD(day, 1, @Manana)), 1);

DECLARE @R1 int, @R2 int, @R3 int, @R4 int;
EXEC dbo.usp_CrearReserva 1, 1, 1, @R1 OUTPUT;
EXEC dbo.usp_CrearReserva 2, 2, 2, @R2 OUTPUT;
EXEC dbo.usp_CrearReserva 3, 3, 3, @R3 OUTPUT;
EXEC dbo.usp_CrearReserva 4, 4, 4, @R4 OUTPUT;
EXEC dbo.usp_RegistrarPago @R1, 1, 50.00, N'PRUEBA-TARJETA-001';
EXEC dbo.usp_RegistrarPago @R2, 2, 50.00, N'PRUEBA-BILLETERA-002';
EXEC dbo.usp_CancelarReserva @R4;
GO

-- 6. Consultas administrativas de comprobacion (solo lectura).
-- 6.1 Conteos: Paciente 5, Servicio 6, Agenda 8, MedioPago 2, Reserva 4, Pago 2.
SELECT N'Paciente' AS Tabla, COUNT(*) AS Registros FROM dbo.Paciente
UNION ALL SELECT N'Servicio', COUNT(*) FROM dbo.Servicio
UNION ALL SELECT N'Agenda', COUNT(*) FROM dbo.Agenda
UNION ALL SELECT N'MedioPago', COUNT(*) FROM dbo.MedioPago
UNION ALL SELECT N'Reserva', COUNT(*) FROM dbo.Reserva
UNION ALL SELECT N'Pago', COUNT(*) FROM dbo.Pago;

-- 6.2 Estado de agenda: 3 ocupados, 4 disponibles, 1 deshabilitado.
SELECT a.AgendaID, a.Inicio, a.Fin,
    CASE WHEN a.Habilitada = 0 THEN N'Deshabilitado'
         WHEN a.Inicio <= SYSDATETIME() THEN N'Pasado'
         WHEN r.ReservaID IS NOT NULL THEN N'Ocupado'
         ELSE N'Disponible' END AS Disponibilidad
FROM dbo.Agenda AS a
LEFT JOIN dbo.Reserva AS r ON r.AgendaID = a.AgendaID AND r.Estado <> 'CANCELADA'
ORDER BY a.Inicio;

-- 6.3 Seguimiento de reservas, con y sin pago.
SELECT r.ReservaID, p.NombreCompleto, s.Nombre AS Servicio, a.Inicio,
       r.Estado, r.ImporteReserva, pg.Importe AS ImportePagado, mp.Nombre AS MedioPago
FROM dbo.Reserva AS r
JOIN dbo.Paciente AS p ON p.PacienteID = r.PacienteID
JOIN dbo.Servicio AS s ON s.ServicioID = r.ServicioID
JOIN dbo.Agenda AS a ON a.AgendaID = r.AgendaID
LEFT JOIN dbo.Pago AS pg ON pg.ReservaID = r.ReservaID
LEFT JOIN dbo.MedioPago AS mp ON mp.MedioPagoID = pg.MedioPagoID
ORDER BY a.Inicio;

-- 6.4 Pagos registrados: total ficticio de S/ 100.00.
SELECT mp.Nombre AS MedioPago, COUNT(pg.PagoID) AS Cantidad,
       COALESCE(SUM(CASE WHEN pg.Anulado = 0 THEN pg.Importe ELSE 0 END), 0) AS TotalPEN
FROM dbo.MedioPago AS mp
LEFT JOIN dbo.Pago AS pg ON pg.MedioPagoID = mp.MedioPagoID
GROUP BY mp.MedioPagoID, mp.Nombre;
GO
SET NOEXEC OFF;
GO
