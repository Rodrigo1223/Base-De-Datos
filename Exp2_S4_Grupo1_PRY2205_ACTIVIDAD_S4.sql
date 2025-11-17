SELECT
    TO_CHAR(t.numrut, '99G999G999') || '-' || t.dvrut AS "RUT Trabajador",
    INITCAP(t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno) AS "Nombre Completo Trabajador",
    tt.desc_categoria AS "Tipo Trabajador", 
    INITCAP(c.nombre_ciudad) AS "Ciudad Trabajador",
    TO_CHAR(ROUND(t.sueldo_base), 'FM$9G999G990') AS "Sueldo Base"
FROM
    TRABAJADOR t
JOIN
    TIPO_TRABAJADOR tt ON (t.id_categoria_t = tt.id_categoria)
JOIN
    COMUNA_CIUDAD c ON (t.id_ciudad = c.id_ciudad)
WHERE
    t.sueldo_base BETWEEN 650000 AND 3000000
ORDER BY
    "Ciudad Trabajador" DESC,
    t.sueldo_base ASC;
    
    SELECT
    TO_CHAR(t.numrut, '99G999G999') || '-' || t.dvrut AS "RUT Trabajador",
    INITCAP(t.nombre || ' ' || t.appaterno) AS "Nombre Trabajador",
    COUNT(tk.nro_ticket) AS "Total Tickets",
    TO_CHAR(ROUND(SUM(tk.monto_ticket)), 'FM$9G999G990') AS "Total Vendido",
    TO_CHAR(ROUND(SUM(c.valor_comision)), 'FM$9G999G990') AS "Comisión Total",
    tt.desc_categoria AS "Tipo Trabajador",
    INITCAP(cd.nombre_ciudad) AS "Ciudad Trabajador"
FROM
    TRABAJADOR t
JOIN
    TIPO_TRABAJADOR tt ON (t.id_categoria_t = tt.id_categoria)
JOIN
    TICKETS_CONCIERTO tk ON (t.numrut = tk.numrut_t)
JOIN
    COMISIONES_TICKET c ON (tk.nro_ticket = c.nro_ticket)
JOIN
    COMUNA_CIUDAD cd ON (t.id_ciudad = cd.id_ciudad)
WHERE
    tt.desc_categoria = 'CAJERO' -- Corregido a desc_categoria
GROUP BY
    t.numrut, t.dvrut, t.nombre, t.appaterno, tt.desc_categoria, cd.nombre_ciudad
HAVING
    SUM(tk.monto_ticket) > 50000
ORDER BY
    "Total Vendido" DESC;
    
    
   SELECT
    TO_CHAR(t.numrut, '99G999G999') || '-' || t.dvrut AS "RUT Trabajador",
    INITCAP(t.nombre || ' ' || t.appaterno) AS "Nombre Trabajador",
    EXTRACT(YEAR FROM t.fecing) AS "Año Ingreso",
    TRUNC(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12) AS "Años Antigüedad",
    NVL(COUNT(cf.numrut_carga), 0) AS "Num. Cargas Familiares",
    i.nombre_isapre AS "Nombre Isapre",
    TO_CHAR(ROUND(t.sueldo_base), '9G999G999') AS "Sueldo Base",
    TO_CHAR(ROUND(
        CASE
            WHEN i.nombre_isapre = 'FONASA' THEN t.sueldo_base * 0.01 -- Corregido a mayúsculas
            ELSE 0
        END
    ), '9G990') AS "Bono Fonasa",
    TO_CHAR(ROUND(t.sueldo_base * CASE
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12) <= 10 THEN 0.10
            ELSE 0.15
        END
    ), '9G999G990') AS "Bono Antigüedad",
    afp.nombre_afp AS "Nombre AFP",
    ec.desc_estcivil AS "Estado Civil"
FROM
    TRABAJADOR t
JOIN
    ISAPRE i ON (t.cod_isapre = i.cod_isapre)
JOIN
    AFP afp ON (t.cod_afp = afp.cod_afp)
JOIN
    EST_CIVIL ec_t ON (t.numrut = ec_t.numrut_t) -- Nombre de tabla corregido
JOIN
    ESTADO_CIVIL ec ON (ec_t.id_estcivil_est = ec.id_estcivil)
LEFT JOIN
    ASIGNACION_FAMILIAR cf ON (t.numrut = cf.numrut_t)
WHERE
    ec_t.fecter_estcivil IS NULL OR ec_t.fecter_estcivil > SYSDATE
GROUP BY
    t.numrut, t.dvrut, t.nombre, t.appaterno, t.fecing, t.sueldo_base,
    i.nombre_isapre, afp.nombre_afp, ec.desc_estcivil, ec_t.fecter_estcivil
ORDER BY
    t.numrut ASC; 
    
