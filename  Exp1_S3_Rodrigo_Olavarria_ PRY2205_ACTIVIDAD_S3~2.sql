SET VERIFY OFF;

SELECT
    -- Concatena NUMRUT_CLI y DVRUT_CLI y aplica formato
    TO_CHAR(c.NUMRUT_CLI, 'fm99G999G999') || '-' || c.DVRUT_CLI AS "RUT Formateado",
    -- Concatena Nombre, Apellido Paterno y Apellido Materno
    c.NOMBRE_CLI || ' ' || c.APPATERNO_CLI || ' ' || c.APMATERNO_CLI AS "Nombre Completo",
    c.CELULAR_CLI AS "Nro. Celular", -- CORRECCIÓN APLICADA
    c.RENTA_CLI AS "Renta Mensual",
    -- Clasificación de la Renta
    CASE
        WHEN c.RENTA_CLI <= 500000 THEN 'TRAMO 1'
        WHEN c.RENTA_CLI <= 1000000 THEN 'TRAMO 2'
        WHEN c.RENTA_CLI <= 1500000 THEN 'TRAMO 3'
        ELSE 'TRAMO 4'
    END AS "Tramo de Renta"
FROM
    CLIENTE c
WHERE
    c.RENTA_CLI BETWEEN &RENTA_MINIMA AND &RENTA_MAXIMA -- Variables de sustitución
    AND c.CELULAR_CLI IS NOT NULL -- Filtra por celular registrado (CORRECCIÓN APLICADA)
ORDER BY
    "Nombre Completo" ASC;

SELECT
    cat.DESC_CATEGORIA_EMP AS "Categoría Empleado", -- CORRECCIÓN APLICADA
    s.DESC_SUCURSAL AS "Sucursal",
    -- Promedio redondeado a entero (usando SUELDO_EMP)
    ROUND(AVG(e.SUELDO_EMP)) AS PROMEDIO_SUELDO_RAW, -- CORRECCIÓN APLICADA
    -- Promedio formateado a moneda
    TO_CHAR(ROUND(AVG(e.SUELDO_EMP)), 'FM99G999G999G999', 'NLS_NUMERIC_CHARACTERS = ''.,''') AS "Sueldo Promedio"
FROM
    EMPLEADO e
JOIN
    CATEGORIA_EMPLEADO cat ON e.ID_CATEGORIA_EMP = cat.ID_CATEGORIA_EMP -- CORRECCIÓN DE CLAVE APLICADA
JOIN
    SUCURSAL s ON e.ID_SUCURSAL = s.ID_SUCURSAL
GROUP BY
    cat.DESC_CATEGORIA_EMP,
    s.DESC_SUCURSAL
-- Filtra grupos cuyo promedio sea mayor o igual al valor ingresado
HAVING
    ROUND(AVG(e.SUELDO_EMP)) >= &SUELDO_PROMEDIO_MINIMO
ORDER BY
    "Sueldo Promedio" DESC;

SELECT
    tp.DESC_TIPO_PROPIEDAD AS "Tipo de Propiedad", -- CORRECCIÓN APLICADA
    COUNT(p.NRO_PROPIEDAD) AS "Total Propiedades",
    ROUND(AVG(p.VALOR_ARRIENDO)) AS "Promedio Arriendo",
    ROUND(AVG(p.SUPERFICIE)) AS "Promedio Superficie (m²)",
    -- Cálculo de la Razón de Arriendo por m² (redondeado a entero)
    ROUND(AVG(p.VALOR_ARRIENDO) / AVG(p.SUPERFICIE)) AS "Razon Arriendo x m2",
    -- Clasificación de la Razón de Arriendo
    CASE
        WHEN ROUND(AVG(p.VALOR_ARRIENDO) / AVG(p.SUPERFICIE)) <= 1500 THEN 'Económico'
        WHEN ROUND(AVG(p.VALOR_ARRIENDO) / AVG(p.SUPERFICIE)) <= 2500 THEN 'Medio'
        ELSE 'Alto'
    END AS "Clasificación"
FROM
    PROPIEDAD p
JOIN
    TIPO_PROPIEDAD tp ON p.ID_TIPO_PROPIEDAD = tp.ID_TIPO_PROPIEDAD
GROUP BY
    tp.DESC_TIPO_PROPIEDAD -- CORRECCIÓN APLICADA
HAVING
    ROUND(AVG(p.VALOR_ARRIENDO) / AVG(p.SUPERFICIE)) > 1000
ORDER BY
    "Razon Arriendo x m2" DESC;