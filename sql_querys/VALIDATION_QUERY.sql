-- ============================================================
-- VERIFICACIÓN DE CONTEOS POR ENTIDAD (vs. Concentrado PDF)
-- Entidad 26 = SONORA
-- ============================================================

-- 1. NAC, RES y UM combinados (columna izquierda del PDF)
--    Cualquier registro donde Sonora aparezca en alguno de los tres campos
SELECT
    toYear(FECHA_INGRESO)   AS anio,
    COUNT(*)                AS cantidad_nac_res_um
FROM covid_mx_lote2.sonora
WHERE
    ENTIDAD_NAC = 'SONORA'
    OR ENTIDAD_RES = 'SONORA'
    OR ENTIDAD_UM  = 'SONORA'
GROUP BY anio
ORDER BY anio;

-- Esperado: 2020→110378 | 2021→186374 | 2022→140465
--           2023→25754  | 2024→2161   | 2025→1844  | 2026→749


-- 2. NAC y RES (columna central del PDF)
--    Registros donde Sonora aparece en NAC o RES, sin excluir UM
SELECT
    toYear(FECHA_INGRESO)   AS anio,
    COUNT(*)                AS cantidad_nac_res
FROM covid_mx_lote2.sonora
WHERE
    ENTIDAD_NAC = 'SONORA'
    OR ENTIDAD_RES = 'SONORA'
GROUP BY anio
ORDER BY anio;

-- Esperado: 2020→109938 | 2021→185574 | 2022→139846
--           2023→25664  | 2024→2145   | 2025→1834  | 2026→745


-- 3. Solo UM (columna derecha del PDF)
--    Registros donde Sonora aparece en UM pero NO en NAC ni RES
SELECT
    toYear(FECHA_INGRESO)   AS anio,
    COUNT(*)                AS cantidad_solo_um
FROM covid_mx_lote2.sonora
WHERE
    ENTIDAD_UM  = 'SONORA'
    AND (ENTIDAD_NAC != 'SONORA' OR ENTIDAD_NAC IS NULL)
    AND (ENTIDAD_RES != 'SONORA' OR ENTIDAD_RES IS NULL)
GROUP BY anio
ORDER BY anio;

-- Esperado: 2020→440 | 2021→800 | 2022→619
--           2023→90  | 2024→16  | 2025→10  | 2026→4


-- 4. Las tres columnas en una sola consulta (comparación directa)
SELECT
    toYear(FECHA_INGRESO) AS anio,

    COUNT(*) FILTER (WHERE
        ENTIDAD_NAC = 'SONORA' OR ENTIDAD_RES = 'SONORA' OR ENTIDAD_UM = 'SONORA'
    ) AS nac_res_um,

    COUNT(*) FILTER (WHERE
        ENTIDAD_NAC = 'SONORA' OR ENTIDAD_RES = 'SONORA'
    ) AS nac_res,

    COUNT(*) FILTER (WHERE
        ENTIDAD_UM  = 'SONORA'
        AND (ENTIDAD_NAC != 'SONORA' OR ENTIDAD_NAC IS NULL)
        AND (ENTIDAD_RES != 'SONORA' OR ENTIDAD_RES IS NULL)
    ) AS solo_um

FROM covid_mx_lote2.sonora
GROUP BY anio
ORDER BY anio;


-- 5. Sanity check: nac_res_um debe = nac_res + solo_um
--    Si diferencia = 0 en todos los años, datos limpios
SELECT
    anio,
    nac_res_um,
    nac_res + solo_um              AS suma_parciales,
    nac_res_um - (nac_res + solo_um) AS diferencia
FROM (
    SELECT
        toYear(FECHA_INGRESO) AS anio,
        COUNT(*) FILTER (WHERE ENTIDAD_NAC='SONORA' OR ENTIDAD_RES='SONORA' OR ENTIDAD_UM='SONORA') AS nac_res_um,
        COUNT(*) FILTER (WHERE ENTIDAD_NAC='SONORA' OR ENTIDAD_RES='SONORA')                        AS nac_res,
        COUNT(*) FILTER (WHERE ENTIDAD_UM='SONORA'
            AND (ENTIDAD_NAC!='SONORA' OR ENTIDAD_NAC IS NULL)
            AND (ENTIDAD_RES!='SONORA' OR ENTIDAD_RES IS NULL))                                     AS solo_um
    FROM covid_mx_lote2.sonora
    GROUP BY anio
) sub
ORDER BY anio;