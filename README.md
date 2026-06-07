# 🦠 COVID-19 Sonora — ETL Pipeline

![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)
![Polars](https://img.shields.io/badge/Polars-0.20+-CD792C?style=flat-square&logo=polars&logoColor=white)
![ClickHouse](https://img.shields.io/badge/ClickHouse-24+-FFCC01?style=flat-square&logo=clickhouse&logoColor=black)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)
![License](https://img.shields.io/badge/Datos-Dominio%20Público%20SSA-green?style=flat-square)

### Polars · ClickHouse · SSA Open Data · 2020–2026

> Pipeline ETL para procesamiento y análisis de datos epidemiológicos de COVID-19
> filtrados para el estado de Sonora, México.
> **~20 millones de registros nacionales → ~850,000 registros limpios de Sonora.**

```
SSA Open Data (~20M rows)
        │
        ▼
  ┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
  │  Polars ETL     │────▶│  Catalog Homologation │────▶│   ClickHouse    │
  │  scan_csv lazy  │     │  FK → legible values  │     │  MergeTree OLAP │
  └─────────────────┘     └──────────────────────┘     └─────────────────┘
                                                                 │
                                                                 ▼
                                                      SQL Analytical Queries
                                                      (SONORA_ANALISIS.sql)
```

---

## 📁 Estructura del Repositorio

```
covid19-sonora-etl/
│
├── data/
│   ├── backup_lote1/          # ⚠️ Vacía — se genera al correr script_polars_lote1.py
│   │   └── backup_sonora_YYYYMMDD_HHMMSS.csv
│   └── backup_lote2/          # ⚠️ Vacía — se genera al correr script_polars_lote2.py
│       └── backup_sonora_YYYYMMDD_HHMMSS.csv
│
├── data_lote1/                # ⚠️ Vacía — coloca aquí los CSVs sin espacio en nombre
│   ├── COVID19MEXICO2020.csv
│   ├── COVID19MEXICO2021.csv
│   ├── COVID19MEXICO2022.csv
│   ├── COVID19MEXICO2023.csv
│   ├── COVID19MEXICO2024.csv
│   ├── COVID19MEXICO2025.csv
│   └── COVID19MEXICO2026.csv
│
├── data_lote2/                # ⚠️ Vacía — coloca aquí los CSVs con espacio en nombre
│   ├── COVID19MEXICO 2020.csv
│   ├── COVID19MEXICO 2021.csv
│   ├── COVID19MEXICO 2022.csv
│   ├── COVID19MEXICO 2023.csv
│   ├── COVID19MEXICO 2024.csv
│   ├── COVID19MEXICO 2025.csv
│   └── COVID19MEXICO 2026.csv
│
├── scripts/
│   ├── script_polars_lote1.py     # ETL → covid_mx_lote1.sonora
│   └── script_polars_lote2.py     # ETL → covid_mx_lote2.sonora
│
├── sql_queries/
│   └── SONORA_ANALISIS.sql        # Consultas analíticas ClickHouse
│
└── docker-compose.yml             # ClickHouse local
```

> **Nota:** Las carpetas `data_lote1/`, `data_lote2/` y `data/backup_*/` se incluyen
> vacías en el repositorio. Los archivos CSV no se suben por su tamaño (~20M registros),
> pero son de **dominio público** y pueden descargarse directamente de la fuente oficial:
>
> 📥 **[SSA México — Datos Abiertos COVID-19](https://www.gob.mx/salud/documentos/datos-abiertos-152127)**

---

## 🛠 Stack Tecnológico

| Componente      | Tecnología                  | Rol                                      |
| --------------- | --------------------------- | ---------------------------------------- |
| Procesamiento   | Python 3.11+ + Polars 0.20+ | ETL, limpieza, homologación de catálogos |
| Almacenamiento  | ClickHouse 24+              | OLAP columnar, consultas analíticas      |
| Conector        | clickhouse-connect 0.7+     | Inserción Arrow → ClickHouse             |
| Infraestructura | Docker + docker-compose     | ClickHouse local reproducible            |
| Fuente          | SSA Datos Abiertos          | 7 CSVs anuales 2020–2026                 |

---

## ⚙️ Instalación

### 1. Descargar los datos

Los CSVs **no están incluidos** en el repositorio por su tamaño (~20M registros).
Descárgalos desde la fuente oficial:

📥 **[https://www.gob.mx/salud/documentos/datos-abiertos-152127](https://www.gob.mx/salud/documentos/datos-abiertos-152127)**

Coloca los archivos en `data_lote1/` (sin espacio) o `data_lote2/` (con espacio) según corresponda.

### 2. Instalar dependencias

```bash
pip install polars clickhouse-connect pyarrow
```

### 3. Levantar ClickHouse

```bash
docker-compose up -d
# Disponible en localhost:8123 (HTTP) y localhost:9000 (TCP)
```

---

## 🔄 Ejecución del Pipeline

```bash
# Lote 1 (nombres de archivo sin espacio)
python scripts/script_polars_lote1.py

# Lote 2 (nombres de archivo con espacio)
python scripts/script_polars_lote2.py
```

Cada script:

1. Carga los 7 CSVs con evaluación lazy (Polars `LazyFrame`)
2. Concatena con `diagonal_relaxed` para tolerar diferencias de esquema entre años
3. Filtra por Sonora: `ENTIDAD_RES == 26 OR ENTIDAD_NAC == 26 OR ENTIDAD_UM == 26`
4. Deduplica con `.unique()`
5. Homologa catálogos: códigos numéricos → etiquetas descriptivas
6. **Genera backup CSV automático** en `data/backup_loteN/` con timestamp
7. Solicita confirmación interactiva `[Y/N]` antes de tocar ClickHouse
8. Inserta en ClickHouse vía Apache Arrow (`insert_arrow`)

---

## 🗄️ Bases de Datos en ClickHouse

| Base             | Tabla    | Script origen            | Descripción                        |
| ---------------- | -------- | ------------------------ | ---------------------------------- |
| `covid_mx_lote1` | `sonora` | `script_polars_lote1.py` | Primera carga — CSVs sin espacio   |
| `covid_mx_lote2` | `sonora` | `script_polars_lote2.py` | Segunda carga — CSVs con espacio   |

Ambas tablas tienen esquema idéntico inferido automáticamente desde los dtypes de Polars,
con `ENGINE = MergeTree() ORDER BY tuple()`.

### Validación cruzada entre lotes

```sql
SELECT 'covid_mx_lote1' AS base, COUNT(*) AS total FROM covid_mx_lote1.sonora
UNION ALL
SELECT 'covid_mx_lote2' AS base, COUNT(*) AS total FROM covid_mx_lote2.sonora;
```

---

## 🔑 Catálogos (FK → Valor)

| Columna                                              | Ejemplo FK        | Valor resuelto                  |
| ---------------------------------------------------- | ----------------- | ------------------------------- |
| `ORIGEN`                                             | `1`               | `USMER`                         |
| `SECTOR`                                             | `4`               | `IMSS`                          |
| `SEXO`                                               | `2`               | `HOMBRE`                        |
| `TIPO_PACIENTE`                                      | `2`               | `HOSPITALIZADO`                 |
| `ENTIDAD_RES`                                        | `26`              | `SONORA`                        |
| `CLASIFICACION_FINAL`                                | `3`               | `CASO DE SARS-COV-2 CONFIRMADO` |
| `RESULTADO_LAB`                                      | `1`               | `POSITIVO A SARS-COV-2`         |
| `DIABETES` / `HIPERTENSION` / `OBESIDAD` (y 17 más) | `1` / `2` / `97`  | `SI` / `NO` / `null`            |

> Los valores centinela `97`, `98` y `99` se convierten a `null` durante la homologación.

---

## 🔍 Consultas SQL (SONORA_ANALISIS.sql)

```sql
-- Mortalidad diaria
SELECT toStartOfDay(FECHA_DEF) AS fecha, count() AS fallecidos
FROM covid_mx_lote2.sonora WHERE FECHA_DEF IS NOT NULL
GROUP BY fecha ORDER BY fecha;

-- Mortalidad anual por sexo
SELECT CAST(YEAR(FECHA_DEF) AS INT) AS anio,
       SUM(CASE WHEN SEXO = 'HOMBRE' THEN 1 ELSE 0 END) AS hombres,
       SUM(CASE WHEN SEXO = 'MUJER'  THEN 1 ELSE 0 END) AS mujeres,
       COUNT(*) AS total
FROM covid_mx_lote2.sonora
WHERE ENTIDAD_RES = 'SONORA' AND FECHA_DEF IS NOT NULL
GROUP BY anio ORDER BY anio;

-- Intervalos clínicos (síntomas → ingreso → defunción)
SELECT
    dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO) AS dias_hasta_atencion,
    dateDiff('day', FECHA_INGRESO,  FECHA_DEF)     AS dias_hospitalizacion,
    dateDiff('day', FECHA_SINTOMAS, FECHA_DEF)     AS dias_total_enfermedad
FROM covid_mx_lote2.sonora
WHERE FECHA_SINTOMAS IS NOT NULL
  AND FECHA_INGRESO  IS NOT NULL
  AND FECHA_DEF      IS NOT NULL;

-- Tasa de mortalidad 2020 (población INEGI Censo 2020)
SELECT
    YEAR(FECHA_DEF)                          AS anio,
    COUNT(*)                                 AS total_muertes,
    ROUND(COUNT(*) / 2944840 * 100, 4)       AS tasa_general_pct
FROM covid_mx_lote2.sonora
WHERE ENTIDAD_RES = 'SONORA'
  AND FECHA_DEF IS NOT NULL
  AND YEAR(FECHA_DEF) = 2020
GROUP BY YEAR(FECHA_DEF);
```

---

## 📊 Métricas

| Métrica                          | Valor          |
| -------------------------------- | -------------- |
| Registros nacionales procesados  | ~20,000,000    |
| Registros Sonora (post-filtro)   | ~850,000       |
| Pacientes fallecidos             | ~38,000        |
| Columnas por registro            | 40             |
| Duplicados eliminados            | < 0.01%        |
| Catálogos homologados            | 12 dimensiones |
| Completitud post-limpieza        | > 98%          |

---

## 👤 Autor

**Styveen Emiliano Rizo Hernández**
Ingeniería en Desarrollo y Gestión de Software Multiplataforma
Universidad Tecnológica de Puebla · 9° Cuatrimestre · 2026

---

Fuente de datos: SSA México — Datos Abiertos COVID-19 · Uso exclusivo académico · Dominio público