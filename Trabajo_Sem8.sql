-- ***************************************************************
-- 1. CASO 1: ESTRATEGIA DE SEGURIDAD
-- Ejecutado por el administrador (SYS/SYSTEM)
-- ***************************************************************

-- 1.1. Limpieza de Objetos de Seguridad
DROP USER PRY2205_USER1 CASCADE;
DROP USER PRY2205_USER2 CASCADE;
DROP ROLE PRY2205_ROL_D;
DROP ROLE PRY2205_ROL_P;

-- 1.2. Creación de Roles
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_P;

-- 1.3. Asignación de Privilegios a Roles
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SYNONYM TO PRY2205_ROL_D;
GRANT CONNECT TO PRY2205_ROL_P;

-- 1.4. Creación de Usuarios y Asignación de Roles
CREATE USER PRY2205_USER1 IDENTIFIED BY U1_P
    DEFAULT TABLESPACE users
    QUOTA UNLIMITED ON users;
GRANT PRY2205_ROL_D TO PRY2205_USER1;

CREATE USER PRY2205_USER2 IDENTIFIED BY U2_P
    DEFAULT TABLESPACE users
    QUOTA 0M ON users; 
GRANT PRY2205_ROL_P TO PRY2205_USER2;

-- 1.5. Otorgar permisos para crear sinónimos públicos
GRANT CREATE PUBLIC SYNONYM TO PRY2205_USER1;
GRANT DROP PUBLIC SYNONYM TO PRY2205_USER1;


-- ***************************************************************
-- BLOQUE DE EJECUCIÓN 2: OBJETOS E INFORMES (FINAL CORRECCIÓN)
-- EJECUTADO POR: PRY2205_USER1 (Dueño y Desarrollador)
-- ***************************************************************

-- 2.1. LIMPIEZA DE OBJETOS EXISTENTES (PARA RE-EJECUCIONES LIMPIAS)
DROP PUBLIC SYNONYM ALUMNO;
DROP SYNONYM S_ALUMNO;
DROP PUBLIC SYNONYM PRESTAMO;
DROP SYNONYM S_PRESTAMO;
DROP PUBLIC SYNONYM LIBRO;
DROP SYNONYM S_LIBRO;
DROP PUBLIC SYNONYM EJEMPLAR;
DROP SYNONYM S_EJEMPLAR;
DROP PUBLIC SYNONYM CARRERA;
DROP SYNONYM S_CARRERA;
DROP PUBLIC SYNONYM VALOR_MULTA_PRESTAMO;
DROP SYNONYM S_VMP;
DROP PUBLIC SYNONYM REBAJA_MULTA;
DROP SYNONYM S_RM;
-- Limpieza de informes y de índice (nuevo)
DROP PUBLIC SYNONYM CONTROL_STOCK_LIBROS;
DROP PUBLIC SYNONYM VW_DETALLE_MULTAS;
DROP TABLE CONTROL_STOCK_LIBROS CASCADE CONSTRAINTS;
DROP VIEW VW_DETALLE_MULTAS;
DROP INDEX IDX_PRESTAMO_FECHAS;


-- 2.2. Creación de Sinónimos (Caso 1)
CREATE PUBLIC SYNONYM ALUMNO FOR ALUMNO;
CREATE SYNONYM S_ALUMNO FOR ALUMNO;
CREATE PUBLIC SYNONYM PRESTAMO FOR PRESTAMO;
CREATE SYNONYM S_PRESTAMO FOR PRESTAMO;
CREATE PUBLIC SYNONYM LIBRO FOR LIBRO;
CREATE SYNONYM S_LIBRO FOR LIBRO;
CREATE PUBLIC SYNONYM EJEMPLAR FOR EJEMPLAR;
CREATE SYNONYM S_EJEMPLAR FOR EJEMPLAR;
CREATE PUBLIC SYNONYM CARRERA FOR CARRERA;
CREATE SYNONYM S_CARRERA FOR CARRERA;
CREATE PUBLIC SYNONYM VALOR_MULTA_PRESTAMO FOR VALOR_MULTA_PRESTAMO;
CREATE SYNONYM S_VMP FOR VALOR_MULTA_PRESTAMO;
CREATE PUBLIC SYNONYM REBAJA_MULTA FOR REBAJA_MULTA;
CREATE SYNONYM S_RM FOR REBAJA_MULTA;


-- 2.3. Otorgar Permisos de Lectura (SELECT) al rol de consulta (Caso 1)
GRANT SELECT ON ALUMNO TO PRY2205_ROL_P;
GRANT SELECT ON PRESTAMO TO PRY2205_ROL_P;
GRANT SELECT ON LIBRO TO PRY2205_ROL_P;
GRANT SELECT ON EJEMPLAR TO PRY2205_ROL_P;
GRANT SELECT ON CARRERA TO PRY2205_ROL_P;
GRANT SELECT ON VALOR_MULTA_PRESTAMO TO PRY2205_ROL_P;
GRANT SELECT ON REBAJA_MULTA TO PRY2205_ROL_P;

-- 2.4. Informe de Stock Bibliográfico (Caso 2: CTAS)

CREATE TABLE CONTROL_STOCK_LIBROS AS
WITH Pruebas_Prestamos AS (
    SELECT
        l.libroid,
        COUNT(p.prestamoid) AS ejemplares_en_prestamo
    FROM
        S_PRESTAMO p
    JOIN
        S_LIBRO l ON p.libroid = l.libroid
    WHERE
        EXTRACT(YEAR FROM p.fecha_inicio) = EXTRACT(YEAR FROM SYSDATE) - 2
    GROUP BY
        l.libroid
)
SELECT
    l.libroid AS id_libro,
    l.nombre_libro AS nombre_libro,
    (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid) AS total_ejemplares,
    NVL(pp.ejemplares_en_prestamo, 0) AS ejemplares_prestamo,
    (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid) - NVL(pp.ejemplares_en_prestamo, 0) AS ejemplares_disponibles,
    ROUND((NVL(pp.ejemplares_en_prestamo, 0) / (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid)) * 100) AS porc_prestamo,
    CASE
        WHEN ROUND((NVL(pp.ejemplares_en_prestamo, 0) / (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid)) * 100) > 80 THEN 'Alto'
        WHEN ROUND((NVL(pp.ejemplares_en_prestamo, 0) / (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid)) * 100) > 50 THEN 'Medio'
        ELSE 'Bajo'
    END AS indicador_uso
FROM
    S_LIBRO l
LEFT JOIN
    Pruebas_Prestamos pp ON l.libroid = pp.libroid
WHERE
    (SELECT COUNT(e.ejemplarid) FROM S_EJEMPLAR e WHERE e.libroid = l.libroid) > 0
ORDER BY
    l.libroid;

GRANT SELECT ON CONTROL_STOCK_LIBROS TO PRY2205_ROL_P;
-- CORRECCIÓN FINAL: Se especifica el esquema del dueño del objeto.
CREATE PUBLIC SYNONYM CONTROL_STOCK_LIBROS FOR PRY2205_USER1.CONTROL_STOCK_LIBROS;


-- 2.5. Vista de Detalle de Multas (Caso 3: VIEW)
CREATE OR REPLACE VIEW VW_DETALLE_MULTAS AS
WITH Atrasos_Calculados AS (
    SELECT
        p.prestamoid,
        TRUNC(p.fecha_entrega - p.fecha_termino) AS dias_atraso,
        a.alumnoid,
        c.carreraid,
        l.nombre_libro
    FROM
        S_PRESTAMO p
    JOIN
        S_ALUMNO a ON p.alumnoid = a.alumnoid
    JOIN
        S_CARRERA c ON a.carreraid = c.carreraid
    JOIN
        S_LIBRO l ON p.libroid = l.libroid
    WHERE
        EXTRACT(YEAR FROM p.fecha_termino) = EXTRACT(YEAR FROM SYSDATE) - 2
        AND p.fecha_entrega > p.fecha_termino
)
SELECT
    ac.prestamoid,
    ac.nombre_libro AS libro,
    (a.nombre || ' ' || a.apaterno || ' ' || a.amaterno) AS alumno,
    c.descripcion AS carrera,
    ac.dias_atraso AS dias_atraso_devolucion,
    ROUND(
        (SELECT vmp.valor_multa FROM S_VMP vmp
         WHERE ac.dias_atraso >= vmp.cant_dias_ini
         AND ac.dias_atraso < vmp.cant_dias_ter
        )
    ) AS valor_multa_base,
    ROUND(
        (SELECT vmp.valor_multa FROM S_VMP vmp
         WHERE ac.dias_atraso >= vmp.cant_dias_ini
         AND ac.dias_atraso < vmp.cant_dias_ter
        ) *
        (1 - NVL((SELECT rm.porc_rebaja_multa FROM S_RM rm WHERE rm.carreraid = ac.carreraid) / 100, 0))
    ) AS multa_neta
FROM
    Atrasos_Calculados ac
JOIN
    S_ALUMNO a ON ac.alumnoid = a.alumnoid
JOIN
    S_CARRERA c ON ac.carreraid = c.carreraid
ORDER BY
    ac.prestamoid;

GRANT SELECT ON VW_DETALLE_MULTAS TO PRY2205_ROL_P;
-- CORRECCIÓN FINAL: Se especifica el esquema del dueño del objeto.
CREATE PUBLIC SYNONYM VW_DETALLE_MULTAS FOR PRY2205_USER1.VW_DETALLE_MULTAS;


-- 2.6. Creación de Índices (Caso 4: Optimización)
CREATE INDEX IDX_PRESTAMO_FECHAS ON PRESTAMO (FECHA_TERMINO, FECHA_ENTREGA);
EXEC DBMS_STATS.GATHER_TABLE_STATS (ownname => 'PRY2205_USER1', tabname => 'PRESTAMO', estimate_percent => 100, cascade => TRUE);


-- ***************************************************************
-- BLOQUE DE EJECUCIÓN 3: VALIDACIÓN
-- EJECUTADO POR: PRY2205_USER2 (Consultor/Planificador)
-- ***************************************************************

-- 3.1. Consulta del Informe de Stock (Caso 2)
SELECT * FROM CONTROL_STOCK_LIBROS
WHERE indicador_uso = 'Alto';

-- 3.2. Consulta del Detalle de Multas (Caso 3)
SELECT * FROM VW_DETALLE_MULTAS
WHERE multa_neta > 0;