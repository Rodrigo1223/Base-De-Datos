SET VERIFY OFF;
SET ECHO OFF;

-- =================================================================================
-- CASO 1: Análisis de Facturas
-- =================================================================================

SELECT
    f.numfactura AS "N° Factura",
    -- Formato de fecha 'DD de Mes' en español
    TO_CHAR(f.fecha, 'DD "de" Month', 'NLS_DATE_LANGUAGE=SPANISH') AS "Fecha Emisión",

    -- RUT de 10 caracteres, rellenando con '0' a la izquierda (LPAD)
    LPAD(f.rutcliente, 10, '0') AS "RUT Cliente",

    -- Montos usando las columnas NETO, IVA y TOTAL
    TO_CHAR(f.neto, 'FM$99G999G990') AS "Monto Neto",
    TO_CHAR(f.iva, 'FM$99G999G990') AS "Monto Iva",
    TO_CHAR(f.total, 'FM$99G999G990') AS "Total/Factura",

    -- Clasificación del monto total (CASE)
    CASE
        WHEN f.total BETWEEN 0 AND 50000 THEN 'Bajo'
        WHEN f.total BETWEEN 50001 AND 100000 THEN 'Medio'
        ELSE 'Alto'
    END AS "Categoría Monto",

    -- Clasificación de la forma de pago (DECODE)
    DECODE(f.codpago,
        1, 'EFECTIVO',
        2, 'TARJETA DEBITO',
        3, 'TARJETA CREDITO',
        'CHEQUE'
    ) AS "Forma de pago"
FROM
    factura f
WHERE
    -- Filtro paramétrico: facturas del año anterior
    EXTRACT(YEAR FROM f.fecha) = EXTRACT(YEAR FROM SYSDATE) - 1
ORDER BY
    f.fecha DESC,
    f.neto DESC;


-- =================================================================================
-- CASO 2: Clasificación de Clientes
-- =================================================================================

SELECT
    -- RUT con padding de '*' a la izquierda (LPAD)
    LPAD(c.rutcliente, 14, '*') AS "RUT",

    -- Nombre con iniciales en mayúsculas (INITCAP)
    INITCAP(c.nombre) AS "Cliente",

    -- Manejo de valores nulos para el teléfono (NVL)
    NVL(TO_CHAR(c.telefono), 'Sin teléfono') AS "TELÉFONO",

    -- Manejo de valores nulos para el código de comuna (NVL)
    NVL(TO_CHAR(c.codcomuna), 'Sin comuna') AS "COMUNA",

    c.estado AS "ESTADO",

    -- Categorización del crédito (CASE)
    CASE
        -- Bueno: Saldo/Crédito < 50%. Muestra la diferencia.
        WHEN c.saldo / c.credito < 0.5 THEN
            'Bueno (' || TO_CHAR(c.credito - c.saldo, 'FM$999G999G990') || ')'
        -- Regular: Saldo/Crédito entre 50% y 80%. Muestra el saldo.
        WHEN c.saldo / c.credito BETWEEN 0.5 AND 0.8 THEN
            'Regular (' || TO_CHAR(c.saldo, 'FM$999G999G990') || ')'
        -- Crítico: Saldo/Crédito > 80%.
        ELSE
            'Crítico'
    END AS "Estado Crédito",

    -- Extracción del dominio del correo (SUBSTR, INSTR)
    NVL(
        SUBSTR(c.mail, INSTR(c.mail, '@') + 1),
        'Correo no registrado'
    ) AS "Dominio Correo"

FROM
    cliente c
WHERE
    -- Filtro: Clientes con estado 'A' y crédito disponible
    c.estado = 'A' AND c.credito > 0
ORDER BY
    c.nombre ASC;


-- =================================================================================
-- CASO 3: Stock de productos
-- =================================================================================

SELECT
    p.codproducto AS "ID",
    p.descripcion AS "Descripción de Producto",

    -- Muestra el valor de compra en USD, manejando nulos (NVL)
    NVL(TO_CHAR(p.valorcompradolar, 'FM99D00 "USD"'), 'Sin registro') AS "Compra en USD",

    -- Convierte USD a CLP (con variable &TIPOCAMBIO_DOLAR), redondea y formatea
    CASE
        WHEN p.valorcompradolar IS NULL THEN 'Sin registro'
        ELSE TO_CHAR(ROUND(p.valorcompradolar * &TIPOCAMBIO_DOLAR), 'FM$99G999G990 "PESOS"')
    END AS "USD convertido",

    p.totalstock AS "Stock",

    -- Genera alertas de stock en base a los umbrales (&UMBRAL_BAJO, &UMBRAL_ALTO)
    CASE
        WHEN p.totalstock IS NULL THEN 'Sin datos'
        WHEN p.totalstock < &UMBRAL_BAJO THEN '¡ ALERTA stock muy bajo!'
        WHEN p.totalstock BETWEEN &UMBRAL_BAJO AND &UMBRAL_ALTO THEN '¡Reabastecer pronto!'
        ELSE 'OK'
    END AS "Alerta Stock",

    -- Calcula el precio de oferta (10% de descuento) si el stock es > 80 (Usando VUNITARIO)
    CASE
        WHEN p.totalstock > 80 THEN
            TO_CHAR(ROUND(p.vunitario * 0.9), 'FM$99G999G990')
        ELSE
            'N/A'
    END AS "Precio Oferta"

FROM
    producto p
WHERE
    -- Filtro: Descripción contiene 'zapato' (UPPER) y procedencia 'i'
    UPPER(p.descripcion) LIKE UPPER('%zapato%')
    AND p.procedencia = 'i'
ORDER BY
    p.codproducto DESC;

EXIT;