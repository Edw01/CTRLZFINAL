-- ============================================================================
-- Proyecto #3 - INFO1128 Interfaces Gráficas
-- Script SQL para crear la tabla Aire en SQLite (HeidiSQL 12.3 Portable)
-- ============================================================================

CREATE TABLE IF NOT EXISTS Aire (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    MP25 INTEGER NOT NULL,
    Fecha TEXT NOT NULL,
    Hora TEXT NOT NULL
);

-- Consulta para verificar los datos recibidos en tiempo real en HeidiSQL:
SELECT id, MP25, Fecha, Hora FROM Aire ORDER BY id DESC;

