-- ------------------------------------------------------------------------------------
-- A. LIMPIEZA Y PREPARACIÓN 
-- ------------------------------------------------------------------------------------

BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW V_AUMENTOS_ESTUDIOS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SYNONYM syn_trabajador';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SYNONYM syn_vista_aumentos';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SYNONYM syn_bono_antiguedad';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SYNONYM syn_tickets_concierto';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SYNONYM syn_isapre';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX idx_trab_apmat_upper';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Vaciar la tabla de bonificaciones
TRUNCATE TABLE DETALLE_BONIFICACIONES_TRABAJADOR;

ALTER SESSION SET NLS_DATE_FORMAT='DD/MM/RRRR';

-- ------------------------------------------------------------------------------------
-- B. CREACIÓN DE SINÓNIMOS (Criterio 2) E ÍNDICE (Criterio 4)
-- ------------------------------------------------------------------------------------
CREATE SYNONYM syn_trabajador FOR PRY2205_S7.trabajador;
CREATE SYNONYM syn_bono_antiguedad FOR PRY2205_S7.bono_antiguedad;
CREATE SYNONYM syn_tickets_concierto FOR PRY2205_S7.tickets_concierto;

CREATE INDEX idx_trab_apmat_upper
ON trabajador (UPPER(apmaterno));

-- ------------------------------------------------------------------------------------
-- C. CASO 1: BONIFICACIÓN DE TRABAJADORES (DML)
-- ------------------------------------------------------------------------------------
/*
-- Cumple: Lógica de bonificación, NonEquiJoin, Subconsulta jerárquica, 
-- Secuencia (Criterio 5) y Filtros de datos.
*/
INSERT INTO DETALLE_BONIFICACIONES_TRABAJADOR (
    num, rut, nombre_trabajador, sueldo_base, num_ticket, direccion, sistema_salud, monto, 
    bonif_x_ticket, simulacion_x_ticket, simulacion_antiguedad
)
SELECT
    SEQ_DET_BONIF.NEXTVAL AS NUM, 
    T.numrut || '-' || T.dvrut AS RUT,
    T.nombre || ' ' || T.appaterno || ' ' || T.apmaterno AS NOMBRE_TRABAJADOR,
    TO_CHAR(T.sueldo_base, 'FM9G999G999') AS SUELDO_BASE,
    NVL(TO_CHAR(TC_MAX.nro_ticket), 'No hay info') AS NUM_TICKET,
    T.direccion || ', ' || CC.nombre_ciudad AS DIRECCION,
    A.nombre_afp || ' / ' || I.nombre_isapre AS SISTEMA_SALUD,
    NVL(TO_CHAR(ROUND(TC_MAX.monto_ticket)), 'No hay info') AS MONTO, 
    
    NVL(TO_CHAR(ROUND(
        CASE
            WHEN TC_MAX.monto_ticket IS NULL OR TC_MAX.monto_ticket <= 50000 THEN 0
            WHEN TC_MAX.monto_ticket > 50000 AND TC_MAX.monto_ticket <= 100000 THEN TC_MAX.monto_ticket * 0.05
            WHEN TC_MAX.monto_ticket > 100000 THEN TC_MAX.monto_ticket * 0.07
            ELSE 0
        END
    )), 'No hay info') AS BONIF_X_TICKET,

    NVL(TO_CHAR(ROUND(T.sueldo_base +
        CASE
            WHEN TC_MAX.monto_ticket IS NULL OR TC_MAX.monto_ticket <= 50000 THEN 0
            WHEN TC_MAX.monto_ticket > 50000 AND TC_MAX.monto_ticket <= 100000 THEN TC_MAX.monto_ticket * 0.05
            WHEN TC_MAX.monto_ticket > 100000 THEN TC_MAX.monto_ticket * 0.07
            ELSE 0
        END
    )), TO_CHAR(T.sueldo_base)) AS SIMULACION_X_TICKET,

    TO_CHAR(ROUND(T.sueldo_base * (1 + (BA.porcentaje / 100)))) AS SIMULACION_ANTIGUEDAD
FROM
    trabajador T
JOIN comuna_ciudad CC ON T.id_ciudad = CC.id_ciudad
JOIN afp A ON T.cod_afp = A.cod_afp
JOIN isapre I ON T.cod_isapre = I.cod_isapre
LEFT JOIN (
    SELECT numrut_t, nro_ticket, monto_ticket, 
           ROW_NUMBER() OVER (PARTITION BY numrut_t ORDER BY monto_ticket DESC, nro_ticket DESC) AS rn
    FROM tickets_concierto
) TC_MAX ON T.numrut = TC_MAX.numrut_t AND TC_MAX.rn = 1
JOIN bono_antiguedad BA ON TRUNC(MONTHS_BETWEEN(SYSDATE, T.fecing) / 12) BETWEEN BA.limite_inferior AND BA.limite_superior
WHERE 
    TRUNC(MONTHS_BETWEEN(SYSDATE, T.fecnac) / 12) < 50
    AND (A.porc_descto_afp > 4 OR I.porc_descto_isapre > 4);

COMMIT;

-- ------------------------------------------------------------------------------------
-- D. CASO 2: VISTA V_AUMENTOS_ESTUDIOS (Criterio 3)
-- ------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW V_AUMENTOS_ESTUDIOS (
    RUT, NOMBRE_COMPLETO, NIVEL_EDUCACION, PORC_BONO, SUELDO_ACTUAL, AUMENTO_CALCULADO, SIMULACION_SUELDO
)
AS
SELECT
    T.numrut || '-' || T.dvrut AS RUT,
    T.nombre || ' ' || T.appaterno || ' ' || T.apmaterno AS NOMBRE_COMPLETO,
    BE.descrip AS NIVEL_EDUCACION,
    BE.porc_bono || '%' AS PORC_BONO,
    TO_CHAR(T.sueldo_base, 'FM9G999G999') AS SUELDO_ACTUAL,
    TO_CHAR(ROUND(T.sueldo_base * (BE.porc_bono / 100)), 'FM9G999G999') AS AUMENTO_CALCULADO,
    TO_CHAR(ROUND(T.sueldo_base * (1 + (BE.porc_bono / 100))), 'FM9G999G999') AS SIMULACION_SUELDO
FROM
    trabajador T
JOIN
    bono_escolar BE ON T.id_escolaridad_t = BE.id_escolar
WHERE
    T.id_categoria_t = (SELECT id_categoria FROM tipo_trabajador WHERE desc_categoria = 'CAJERO') 
    OR
    (
        SELECT COUNT(*)
        FROM asignacion_familiar AF
        WHERE AF.numrut_t = T.numrut
    ) IN (1, 2);
    
CREATE SYNONYM syn_vista_aumentos FOR PRY2205_S7.V_AUMENTOS_ESTUDIOS;

-- ------------------------------------------------------------------------------------
-- E. VERIFICACIÓN FINAL
-- ------------------------------------------------------------------------------------
SELECT * FROM detalle_bonificaciones_trabajador
ORDER BY
    TO_NUMBER(REPLACE(REPLACE(SIMULACION_X_TICKET, '.', ''), ',', '')) DESC,
    NOMBRE_TRABAJADOR ASC;

SELECT * FROM syn_vista_aumentos
ORDER BY
    TO_NUMBER(REPLACE(PORC_BONO, '%', '')) ASC,
    NOMBRE_COMPLETO ASC;