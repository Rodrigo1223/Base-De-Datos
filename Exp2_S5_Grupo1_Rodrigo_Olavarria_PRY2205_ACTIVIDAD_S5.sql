-- --------------------------------------------------------------------------
--1: LISTADO DE CLIENTES CON AÑO DE INSCRIPCIÓN SUPERIOR AL PROMEDIO
-- --------------------------------------------------------------------------
SELECT
    TO_CHAR(C.numrun, '99G999G999') || '-' || C.dvrun AS "RUT CLIENTE",
    INITCAP(C.pnombre) || ' ' || INITCAP(C.appaterno) AS "NOMBRE COMPLETO",
    INITCAP(PO.nombre_prof_ofic) AS "PROFESION/OFICIO",
    UPPER(TC.nombre_tipo_cliente) AS "TIPO CLIENTE",
    TO_CHAR(C.fecha_inscripcion, 'YYYY') AS "AÑO INSCRIPCION",
    -- Promedio anual de todos los clientes (Subconsulta en FROM)
    TO_CHAR(T_PROMEDIO.Promedio_Anual, '9999') AS "PROMEDIO AÑOS"
FROM
    CLIENTE C
JOIN
    TIPO_CLIENTE TC ON C.cod_tipo_cliente = TC.cod_tipo_cliente
JOIN
    PROFESION_OFICIO PO ON C.cod_prof_ofic = PO.cod_prof_ofic
JOIN
    (
        -- Subconsulta: Calcula el promedio de los años de inscripción
        SELECT
            ROUND(AVG(EXTRACT(YEAR FROM fecha_inscripcion))) AS Promedio_Anual
        FROM
            CLIENTE
    ) T_PROMEDIO ON 1=1
WHERE
    -- Filtrar clientes cuyo año de inscripción es superior al promedio
    EXTRACT(YEAR FROM C.fecha_inscripcion) > T_PROMEDIO.Promedio_Anual
    AND UPPER(TC.nombre_tipo_cliente) = 'TRABAJADORES DEPENDIENTES'
    AND UPPER(PO.nombre_prof_ofic) IN ('CONTADOR', 'VENDEDOR')
ORDER BY
    C.numrun ASC;


-- --------------------------------------------------------------------------
--2: CREAR TABLA DE CLIENTES CON CUPO SUPERIOR AL MAXIMO DEL AÑO ANTERIOR
-- --------------------------------------------------------------------------

-- Limpia la tabla para asegurar la ejecución (evita ORA-00955)
DROP TABLE CLIENTES_CUPOS_COMPRA CASCADE CONSTRAINTS;

-- Crear la tabla con el resultado de la consulta
CREATE TABLE CLIENTES_CUPOS_COMPRA AS
SELECT
    'RUT:' || TO_CHAR(C.numrun, '99G999G999') || '-' || C.dvrun AS "RUT CLIENTE",
    TRUNC(MONTHS_BETWEEN(SYSDATE, C.fecha_nacimiento) / 12) AS "EDAD",
    '$' || TO_CHAR(TC.cupo_disp_compra, 'FM999G999G990') AS "CUPO DISPONIBLE",
    
    -- Subconsulta para obtener y mostrar el cupo máximo del año anterior
    '$' || TO_CHAR(
        (
            SELECT MAX(cupo_disp_compra)
            FROM TARJETA_CLIENTE
            WHERE EXTRACT(YEAR FROM FECHA_SOLIC_TARJETA) = EXTRACT(YEAR FROM SYSDATE) - 1
        ), 'FM999G990') AS "MAX CUPO AÑO ANTERIOR",
        
    EXTRACT(YEAR FROM SYSDATE) - 1 AS "AÑO COMPARACION"

FROM
    CLIENTE C
JOIN
    TARJETA_CLIENTE TC ON C.numrun = TC.numrun
WHERE
    -- Restricción: el cupo disponible debe ser superior o igual al MAX cupo del año anterior
    TC.cupo_disp_compra >= (
        SELECT MAX(cupo_disp_compra)
        FROM TARJETA_CLIENTE
        WHERE EXTRACT(YEAR FROM FECHA_SOLIC_TARJETA) = EXTRACT(YEAR FROM SYSDATE) - 1
    )
ORDER BY
    "EDAD" ASC;