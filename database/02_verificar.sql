-- Verificacion de solo lectura. No regenera ni elimina datos.
USE PA4_3657_ConsultorioIris;
GO
SET NOCOUNT ON;
SELECT t.name AS Tabla, SUM(p.rows) AS Registros
FROM sys.tables t JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
GROUP BY t.name ORDER BY t.name;
SELECT name AS Procedimiento FROM sys.procedures ORDER BY name;
SELECT AgendaID, COUNT(*) AS ReservasVigentes FROM dbo.Reserva
WHERE Estado <> 'CANCELADA' GROUP BY AgendaID HAVING COUNT(*) > 1;
SELECT r.ReservaID, r.Estado FROM dbo.Reserva r
WHERE (r.Estado = 'CONFIRMADA' AND NOT EXISTS (SELECT 1 FROM dbo.Pago p WHERE p.ReservaID=r.ReservaID AND p.Anulado=0))
   OR (r.Estado <> 'CONFIRMADA' AND EXISTS (SELECT 1 FROM dbo.Pago p WHERE p.ReservaID=r.ReservaID AND p.Anulado=0));
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
GO
