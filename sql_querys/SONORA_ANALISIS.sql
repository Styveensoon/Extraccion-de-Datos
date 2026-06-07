-- =============================================================================
--  COVID-19 México · Sonora · Consultas de Análisis
--  Dataset: SSA 2020–2026  |  Motor: ClickHouse
--  Autor: Styveen Emiliano Rizo Hernández
-- =============================================================================
--  NOTA: todas las consultas usan prefijo explícito de base de datos.
--  Para ejecutar contra lote1 sustituir covid_mx_lote2 por covid_mx_lote1.
-- =============================================================================


-- =============================================================================
--  0. VALIDACIÓN Y EXPLORACIÓN INICIAL
-- =============================================================================

-- 0.1 Conteo de registros por universo de datos
--     Verifica que ambos lotes cargaron correctamente antes de cualquier análisis.
SELECT 'covid_mx_lote1' AS base, COUNT(*) AS total FROM covid_mx_lote1.sonora
UNION ALL
SELECT 'covid_mx_lote2' AS base, COUNT(*) AS total FROM covid_mx_lote2.sonora;

-- -----------------------------------------------------------------------------
-- 0.2 Validación cruzada entre universos (ENTIDAD_RES vs ENTIDAD_UM)
--     Desglosa cuántos registros pertenecen a Sonora por residencia,
--     por unidad médica, o por ambos criterios simultáneamente.
SELECT
    countIf(ENTIDAD_RES = 'SONORA')                              AS solo_residentes,
    countIf(ENTIDAD_UM  = 'SONORA')                              AS solo_atendidos_sonora,
    countIf(ENTIDAD_RES = 'SONORA' AND ENTIDAD_UM = 'SONORA')    AS ambos_criterios,
    count(*)                                                     AS total_dataset
FROM covid_mx_lote2.sonora;

-- -----------------------------------------------------------------------------
-- 0.3 Vista rápida del esquema y primeros registros
--     Útil para confirmar que los tipos de dato y catálogos se homologaron bien.
SELECT *
FROM covid_mx_lote2.sonora
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 0.4 Completitud del dataset por columna
--     Identifica columnas con alta proporción de nulos post-limpieza.
--     Una completitud < 5 % puede indicar columnas candidatas a descarte.
SELECT
    'FECHA_DEF'  AS columna, countIf(FECHA_DEF  IS NULL) / count(*) * 100 AS pct_nulos
FROM covid_mx_lote2.sonora
UNION ALL SELECT 'INTUBADO',  countIf(INTUBADO  IS NULL) / count(*) * 100 FROM covid_mx_lote2.sonora
UNION ALL SELECT 'UCI',       countIf(UCI       IS NULL) / count(*) * 100 FROM covid_mx_lote2.sonora
UNION ALL SELECT 'MIGRANTE',  countIf(MIGRANTE  IS NULL) / count(*) * 100 FROM covid_mx_lote2.sonora
UNION ALL SELECT 'EMBARAZO',  countIf(EMBARAZO  IS NULL) / count(*) * 100 FROM covid_mx_lote2.sonora
ORDER BY pct_nulos DESC;


-- =============================================================================
--  1. MORTALIDAD
-- =============================================================================

-- 1.1 Mortalidad diaria
--     Cuenta las defunciones registradas por día. Permite visualizar curvas
--     de oleadas epidémicas (picos en 2021, descenso post-vacunación).
SELECT
    toStartOfDay(FECHA_DEF) AS fecha,
    count()                 AS total_fallecidos
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY fecha
ORDER BY fecha ASC;

-- -----------------------------------------------------------------------------
-- 1.2 Mortalidad semanal suavizada
--     Agrupa por semana para reducir ruido del reporte diario y evidenciar
--     tendencias de mediano plazo más claramente.
SELECT
    toStartOfWeek(FECHA_DEF, 1) AS semana,
    count()                     AS fallecidos_semana
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY semana
ORDER BY semana ASC;

-- -----------------------------------------------------------------------------
-- 1.3 Mortalidad mensual
--     Nivel de granularidad útil para reportes epidemiológicos oficiales
--     y comparativa entre años calendario.
SELECT
    toStartOfMonth(FECHA_DEF) AS mes,
    count()                   AS fallecidos_mes
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY mes
ORDER BY mes ASC;

-- -----------------------------------------------------------------------------
-- 1.4 Mortalidad anual desagregada por sexo
--     Compara la carga de mortalidad entre hombres y mujeres por año.
--     Los hombres presentan mayor mortalidad en todos los años del dataset.
SELECT
    CAST(YEAR(FECHA_DEF) AS INT)                              AS anio,
    SUM(CASE WHEN SEXO = 'HOMBRE' THEN 1 ELSE 0 END)         AS hombres,
    SUM(CASE WHEN SEXO = 'MUJER'  THEN 1 ELSE 0 END)         AS mujeres,
    COUNT(*)                                                  AS total
FROM covid_mx_lote2.sonora
WHERE ENTIDAD_RES = 'SONORA'
  AND FECHA_DEF   IS NOT NULL
GROUP BY CAST(YEAR(FECHA_DEF) AS INT)
ORDER BY anio;

-- -----------------------------------------------------------------------------
-- 1.5 Tasa de mortalidad poblacional por sexo — año 2020
--     Usa la población de Sonora (INEGI 2020) como denominador para calcular
--     qué porcentaje de cada sexo falleció ese año.
--     Hombres: 1,472,197  |  Mujeres: 1,472,643  |  Total: 2,944,840
SELECT
    YEAR(FECHA_DEF)                                                           AS anio,
    SUM(CASE WHEN SEXO = 'HOMBRE' THEN 1 ELSE 0 END)                         AS muertes_hombres,
    SUM(CASE WHEN SEXO = 'MUJER'  THEN 1 ELSE 0 END)                         AS muertes_mujeres,
    COUNT(*)                                                                  AS total_muertes,
    ROUND(SUM(CASE WHEN SEXO = 'HOMBRE' THEN 1 ELSE 0 END) / 1472197 * 100, 4) AS tasa_hombres_pct,
    ROUND(SUM(CASE WHEN SEXO = 'MUJER'  THEN 1 ELSE 0 END) / 1472643 * 100, 4) AS tasa_mujeres_pct,
    ROUND(COUNT(*) / 2944840 * 100, 4)                                       AS tasa_general_pct
FROM covid_mx_lote2.sonora
WHERE ENTIDAD_RES = 'SONORA'
  AND FECHA_DEF   IS NOT NULL
  AND YEAR(FECHA_DEF) = 2020
  AND SEXO IN ('HOMBRE', 'MUJER')
GROUP BY YEAR(FECHA_DEF);

-- -----------------------------------------------------------------------------
-- 1.6 Tasa de mortalidad poblacional — serie completa 2020–2026
--     Extiende la consulta anterior a todos los años para ver la evolución
--     de la letalidad conforme avanza la pandemia y la vacunación.
SELECT
    YEAR(FECHA_DEF)                              AS anio,
    COUNT(*)                                     AS total_muertes,
    ROUND(COUNT(*) / 2944840 * 100, 4)           AS tasa_mortalidad_pct
FROM covid_mx_lote2.sonora
WHERE ENTIDAD_RES = 'SONORA'
  AND FECHA_DEF   IS NOT NULL
  AND SEXO IN ('HOMBRE', 'MUJER')
GROUP BY YEAR(FECHA_DEF)
ORDER BY anio;

-- -----------------------------------------------------------------------------
-- 1.7 Mortalidad por municipio
--     Identifica los municipios de Sonora con mayor número de defunciones.
--     Hermosillo concentra la mayor carga por ser la capital y mayor centro urbano.
SELECT
    MUNICIPIO_RES   AS municipio,
    count()         AS total_fallecidos
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY municipio
ORDER BY total_fallecidos DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- 1.8 Mortalidad por grupo etario
--     Agrupa por décadas de edad para identificar qué grupos poblacionales
--     concentraron la mayor mortalidad (adultos mayores 60+).
SELECT
    FLOOR(EDAD / 10) * 10   AS grupo_etario_inicio,
    count()                 AS fallecidos
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY grupo_etario_inicio
ORDER BY grupo_etario_inicio ASC;

-- -----------------------------------------------------------------------------
-- 1.9 Mortalidad por sector institucional
--     Compara IMSS, ISSSTE, SSA, privado, etc. para entender qué sector
--     absorbió más decesos y su capacidad de respuesta.
SELECT
    SECTOR          AS sector_salud,
    count()         AS fallecidos
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY sector_salud
ORDER BY fallecidos DESC;


-- =============================================================================
--  2. INTERVALOS CLÍNICOS
-- =============================================================================

-- 2.1 Detalle de intervalos clínicos por paciente fallecido (muestra)
--     Para los primeros 100 pacientes fallecidos muestra los días entre
--     síntomas → ingreso → defunción. Base para detectar rezagos en atención.
SELECT
    ID_REGISTRO,
    SEXO,
    EDAD,
    FECHA_SINTOMAS,
    FECHA_INGRESO,
    FECHA_DEF,
    dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO)  AS dias_hasta_atencion,
    dateDiff('day', FECHA_INGRESO,  FECHA_DEF)      AS dias_hospitalizacion,
    dateDiff('day', FECHA_SINTOMAS, FECHA_DEF)      AS dias_total_enfermedad,
    'FALLECIDO'                                     AS estatus
FROM covid_mx_lote2.sonora
WHERE FECHA_SINTOMAS IS NOT NULL
  AND FECHA_INGRESO  IS NOT NULL
  AND FECHA_DEF      IS NOT NULL
LIMIT 100;

-- -----------------------------------------------------------------------------
-- 2.2 Estadísticos descriptivos de los intervalos clínicos (fallecidos)
--     Calcula media, mediana y desviación estándar de cada intervalo para
--     toda la población fallecida. Valor central del análisis epidemiológico.
SELECT
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO))        AS media_dias_atencion,
    median(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO))     AS mediana_dias_atencion,
    stddevSamp(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO)) AS desv_dias_atencion,

    avg(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))            AS media_dias_hospitalizacion,
    median(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))         AS mediana_dias_hospitalizacion,
    stddevSamp(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))     AS desv_dias_hospitalizacion,

    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))            AS media_dias_total,
    median(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))         AS mediana_dias_total,
    stddevSamp(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))     AS desv_dias_total
FROM covid_mx_lote2.sonora
WHERE FECHA_SINTOMAS IS NOT NULL
  AND FECHA_INGRESO  IS NOT NULL
  AND FECHA_DEF      IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2.3 Intervalos clínicos desagregados por sexo
--     Compara si hombres y mujeres tuvieron tiempos de hospitalización
--     distintos, apoyando el análisis de equidad en atención médica.
SELECT
    SEXO,
    count()                                                      AS n,
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO))          AS media_dias_atencion,
    avg(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))              AS media_dias_hospitalizacion,
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))              AS media_dias_total
FROM covid_mx_lote2.sonora
WHERE FECHA_SINTOMAS IS NOT NULL
  AND FECHA_INGRESO  IS NOT NULL
  AND FECHA_DEF      IS NOT NULL
GROUP BY SEXO;

-- -----------------------------------------------------------------------------
-- 2.4 Intervalos clínicos desagregados por grupo etario
--     Analiza si adultos mayores tuvieron hospitalizaciones más prolongadas
--     (hipótesis: mayor comorbilidad → mayor tiempo hasta defunción).
SELECT
    FLOOR(EDAD / 10) * 10                                        AS grupo_etario,
    count()                                                      AS n,
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO))          AS media_dias_atencion,
    avg(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))              AS media_dias_hospitalizacion,
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))              AS media_dias_total
FROM covid_mx_lote2.sonora
WHERE FECHA_SINTOMAS IS NOT NULL
  AND FECHA_INGRESO  IS NOT NULL
  AND FECHA_DEF      IS NOT NULL
GROUP BY grupo_etario
ORDER BY grupo_etario ASC;


-- =============================================================================
--  3. ESTADÍSTICA DESCRIPTIVA GENERAL
-- =============================================================================

-- 3.1 Estadísticos descriptivos de EDAD (toda la población)
--     Mínimo, máximo, media, mediana y desviación estándar de la edad.
--     El rango 0–120 incluye recién nacidos y casos con edad atípica (a revisar).
SELECT
    min(EDAD)        AS edad_min,
    max(EDAD)        AS edad_max,
    avg(EDAD)        AS edad_media,
    median(EDAD)     AS edad_mediana,
    stddevSamp(EDAD) AS edad_desv_estandar
FROM covid_mx_lote2.sonora;

-- -----------------------------------------------------------------------------
-- 3.2 Distribución por tipo de paciente y sexo
--     Muestra la proporción de pacientes ambulatorios vs hospitalizados
--     cruzado con sexo. Base para evaluar la saturación hospitalaria.
SELECT
    TIPO_PACIENTE,
    SEXO,
    count()  AS total,
    ROUND(count() / (SELECT count() FROM covid_mx_lote2.sonora) * 100, 2) AS pct
FROM covid_mx_lote2.sonora
GROUP BY TIPO_PACIENTE, SEXO
ORDER BY TIPO_PACIENTE, SEXO;

-- -----------------------------------------------------------------------------
-- 3.3 Distribución por clasificación final del caso
--     Cuántos casos fueron confirmados, sospechosos o negativos a COVID-19.
SELECT
    CLASIFICACION_FINAL AS clasificacion,
    count()             AS total,
    ROUND(count() / (SELECT count() FROM covid_mx_lote2.sonora) * 100, 2) AS pct
FROM covid_mx_lote2.sonora
GROUP BY clasificacion
ORDER BY total DESC;

-- -----------------------------------------------------------------------------
-- 3.4 Tasa de ocupación de UCI entre hospitalizados
--     Del total de pacientes hospitalizados, qué porcentaje requirió UCI
--     y qué porcentaje fue intubado. Indicador de severidad.
SELECT
    count()                                            AS total_hospitalizados,
    countIf(UCI      = 'SI')                           AS requirieron_uci,
    countIf(INTUBADO = 'SI')                           AS intubados,
    ROUND(countIf(UCI      = 'SI') / count() * 100, 2) AS pct_uci,
    ROUND(countIf(INTUBADO = 'SI') / count() * 100, 2) AS pct_intubado
FROM covid_mx_lote2.sonora
WHERE TIPO_PACIENTE = 'HOSPITALIZADO';

-- -----------------------------------------------------------------------------
-- 3.5 Prevalencia de comorbilidades en pacientes fallecidos
--     Cuenta cuántos fallecidos tenían cada comorbilidad registrada.
--     Hipertensión, diabetes y obesidad son las más frecuentes en el dataset SSA.
SELECT
    'DIABETES'     AS comorbilidad, countIf(DIABETES      = 'SI' AND FECHA_DEF IS NOT NULL) AS n FROM covid_mx_lote2.sonora
UNION ALL SELECT 'HIPERTENSION',   countIf(HIPERTENSION  = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'OBESIDAD',       countIf(OBESIDAD      = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'CARDIOVASCULAR', countIf(CARDIOVASCULAR= 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'EPOC',           countIf(EPOC          = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'RENAL_CRONICA',  countIf(RENAL_CRONICA = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'INMUSUPR',       countIf(INMUSUPR      = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'TABAQUISMO',     countIf(TABAQUISMO    = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
UNION ALL SELECT 'ASMA',           countIf(ASMA          = 'SI' AND FECHA_DEF IS NOT NULL) FROM covid_mx_lote2.sonora
ORDER BY n DESC;

-- -----------------------------------------------------------------------------
-- 3.6 Total de fallecidos (conteo directo)
--     Verificación rápida del total de defunciones registradas en el dataset.
SELECT count(*) AS total_fallecidos
FROM covid_mx_lote2.sonora
WHERE FECHA_DEF IS NOT NULL;