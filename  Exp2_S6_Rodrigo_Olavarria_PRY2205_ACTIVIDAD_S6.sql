ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
SET LINESIZE 200;
SET PAGESIZE 50;
COLUMN PROFESIONAL FORMAT A45;

------------------------------------------------------------------------------------------------------
-- CASO 1: REPORTERÍA DE ASESORÍAS (Banca y Retail)
------------------------------------------------------------------------------------------------------
PROMPT
PROMPT *** INICIO CASO 1: REPORTE DE ASESORIAS (Banca y Retail) ***
PROMPT

SELECT
    t1.id_profesional AS ID,
    INITCAP(t2.appaterno) || ' ' || INITCAP(t2.apmaterno) || ' ' || INITCAP(t2.nombre) AS PROFESIONAL,
    SUM(CASE WHEN t3.cod_sector = 3 THEN 1 ELSE 0 END) AS NRO_ASESORIA_BANCA,
    -- Redondeo y formato para Monto Total Banca
    TO_CHAR(ROUND(SUM(CASE WHEN t3.cod_sector = 3 THEN t1.honorario ELSE 0 END)), 'FM999G999G999') AS MONTO_TOTAL_BANCA,
    SUM(CASE WHEN t3.cod_sector = 4 THEN 1 ELSE 0 END) AS NRO_ASESORIA_RETAIL,
    -- Redondeo y formato para Monto Total Retail
    TO_CHAR(ROUND(SUM(CASE WHEN t3.cod_sector = 4 THEN t1.honorario ELSE 0 END)), 'FM999G999G999') AS MONTO_TOTAL_RETAIL,
    SUM(CASE WHEN t3.cod_sector IN (3, 4) THEN 1 ELSE 0 END) AS TOTAL_ASESORIAS,
    -- Redondeo y formato para Total Honorarios
    TO_CHAR(ROUND(SUM(CASE WHEN t3.cod_sector IN (3, 4) THEN t1.honorario ELSE 0 END)), 'FM999G999G999') AS TOTAL_HONORARIOS
FROM
    asesoria t1
    JOIN profesional t2 ON t1.id_profesional = t2.id_profesional
    JOIN empresa t3 ON t1.cod_empresa = t3.cod_empresa
WHERE
    t1.id_profesional IN (
        -- Uso de INTERSECT para IDs presentes en Banca (3) Y Retail (4)
        SELECT id_profesional
        FROM asesoria a JOIN empresa e ON a.cod_empresa = e.cod_empresa
        WHERE e.cod_sector = 3
        INTERSECT
        SELECT id_profesional
        FROM asesoria a JOIN empresa e ON a.cod_empresa = e.cod_empresa
        WHERE e.cod_sector = 4
    )
GROUP BY
    t1.id_profesional, t2.appaterno, t2.apmaterno, t2.nombre
ORDER BY
    ID ASC;

------------------------------------------------------------------------------------------------------
-- CASO 2: RESUMEN DE HONORARIOS (DDL - CREATE TABLE AS)
------------------------------------------------------------------------------------------------------
PROMPT
PROMPT *** INICIO CASO 2: CREACIÓN DE TABLA REPORTE_MES ***
PROMPT

-- El ORA-00942 aquí es esperado si la tabla no existe previamente.
DROP TABLE REPORTE_MES CASCADE CONSTRAINTS;

-- Sentencia DDL: Crear y poblar la tabla REPORTE_MES
CREATE TABLE REPORTE_MES AS
SELECT
    t1.id_profesional AS ID_PROF,
    INITCAP(t2.appaterno) || ' ' || INITCAP(t2.apmaterno) || ' ' || INITCAP(t2.nombre) AS NOMBRE_COMPLETO,
    t4.nombre_profesion AS NOMBRE_PROFESION,
    t5.nom_comuna AS NOM_COMUNA,
    COUNT(*) AS NRO_ASESORIAS, -- CORRECCIÓN: Uso de COUNT(*) para contar asesorías
    ROUND(SUM(t1.honorario)) AS MONTO_TOTAL_HONORARIOS,
    ROUND(AVG(t1.honorario)) AS PROMEDIO_HONORARIO,
    ROUND(MIN(t1.honorario)) AS HONORARIO_MINIMO,
    ROUND(MAX(t1.honorario)) AS HONORARIO_MAXIMO
FROM
    asesoria t1
    JOIN profesional t2 ON t1.id_profesional = t2.id_profesional
    JOIN profesion t4 ON t2.cod_profesion = t4.cod_profesion
    JOIN comuna t5 ON t2.cod_comuna = t5.cod_comuna
-- Restricción de Fechas (Paramétrico: Abril del año pasado)
WHERE
    EXTRACT(YEAR FROM t1.fin_asesoria) = EXTRACT(YEAR FROM SYSDATE) - 1
    AND EXTRACT(MONTH FROM t1.fin_asesoria) = 4
GROUP BY
    t1.id_profesional, t2.appaterno, t2.apmaterno, t2.nombre, t4.nombre_profesion, t5.nom_comuna
ORDER BY
    ID_PROF ASC;

PROMPT
PROMPT *** REPORTE DE VERIFICACION DE LA TABLA REPORTE_MES CREADA ***
PROMPT
SELECT * FROM REPORTE_MES;

------------------------------------------------------------------------------------------------------
-- CASO 3: MODIFICACIÓN DE HONORARIOS (DML - UPDATE)
------------------------------------------------------------------------------------------------------
PROMPT
PROMPT *** INICIO CASO 3: REPORTE ANTES DE LA MODIFICACION (Figura 4) ***
PROMPT

-- 1. Reporte de Verificación ANTES de la modificación (Figura 4)
SELECT
    ROUND(hm.HONORARIO_ACUMULADO) AS HONORARIO,
    p.ID_PROFESIONAL,
    p.NUMRUN_PROF,
    p.SUELDO
FROM
    profesional p
    JOIN (
        -- Subconsulta para calcular el total de honorarios de Marzo del año pasado
        SELECT
            t1.id_profesional,
            SUM(t1.honorario) AS HONORARIO_ACUMULADO
        FROM
            asesoria t1
        WHERE
            EXTRACT(YEAR FROM t1.fin_asesoria) = EXTRACT(YEAR FROM SYSDATE) - 1
            AND EXTRACT(MONTH FROM t1.fin_asesoria) = 3
        GROUP BY
            t1.id_profesional
    ) hm ON p.id_profesional = hm.id_profesional
ORDER BY
    p.ID_PROFESIONAL;


PROMPT
PROMPT *** EJECUCION DE LA SENTENCIA DML (UPDATE) ***
PROMPT

-- 2. Sentencia DML de Actualización (UPDATE)
UPDATE profesional p
SET p.sueldo = (
    -- Subconsulta Escalar para determinar el nuevo sueldo
    SELECT
        CASE
            WHEN hm.HONORARIO_ACUMULADO < 1000000 THEN ROUND(p.sueldo * 1.10)  -- 10% de incremento
            WHEN hm.HONORARIO_ACUMULADO >= 1000000 THEN ROUND(p.sueldo * 1.15) -- 15% de incremento
        END
    FROM
        (
            -- Subconsulta para sumar los honorarios de Marzo del año pasado
            SELECT
                id_profesional,
                SUM(honorario) AS HONORARIO_ACUMULADO
            FROM
                asesoria
            WHERE
                EXTRACT(YEAR FROM fin_asesoria) = EXTRACT(YEAR FROM SYSDATE) - 1
                AND EXTRACT(MONTH FROM fin_asesoria) = 3
            GROUP BY
                id_profesional
        ) hm
    WHERE
        p.id_profesional = hm.id_profesional
)
-- Restricción: Solo actualizar a profesionales que realizaron asesorías en el periodo
WHERE
    p.id_profesional IN (
        SELECT id_profesional
        FROM asesoria
        WHERE
            EXTRACT(YEAR FROM fin_asesoria) = EXTRACT(YEAR FROM SYSDATE) - 1
            AND EXTRACT(MONTH FROM fin_asesoria) = 3
    );

-- Confirmar la transacción
COMMIT;


PROMPT
PROMPT *** REPORTE DESPUÉS DE LA MODIFICACION  ***
PROMPT

-- 3. Reporte de Verificación DESPUÉS de la modificación 
SELECT
    ROUND(hm.HONORARIO_ACUMULADO) AS HONORARIO,
    p.ID_PROFESIONAL,
    p.NUMRUN_PROF,
    p.SUELDO
FROM
    profesional p
    JOIN (
        SELECT
            t1.id_profesional,
            SUM(t1.honorario) AS HONORARIO_ACUMULADO
        FROM
            asesoria t1
        WHERE
            EXTRACT(YEAR FROM t1.fin_asesoria) = EXTRACT(YEAR FROM SYSDATE) - 1
            AND EXTRACT(MONTH FROM t1.fin_asesoria) = 3
        GROUP BY
            t1.id_profesional
    ) hm ON p.id_profesional = hm.id_profesional
ORDER BY
    p.ID_PROFESIONAL;

