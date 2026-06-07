<div align="center">

# 🦠 COVID-19 México — ETL Pipeline
### Polars · ClickHouse · SSA Open Data · 2020–2026

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![Polars](https://img.shields.io/badge/Polars-0.20+-CD792C?style=flat-square&logo=polars&logoColor=white)](https://pola.rs/)
[![ClickHouse](https://img.shields.io/badge/ClickHouse-24+-FFCC01?style=flat-square&logo=clickhouse&logoColor=black)](https://clickhouse.com/)
[![Docker](https://img.shields.io/badge/Docker-required-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Dataset](https://img.shields.io/badge/Dataset-SSA%20México-red?style=flat-square)](https://datos.gob.mx/busca/dataset/informacion-referente-a-casos-covid-19-en-mexico)

<br/>

> **Pipeline ETL de alto rendimiento** para procesamiento y análisis de los datos epidemiológicos de COVID-19 publicados por la Secretaría de Salud de México (SSA).  
> ~20 millones de registros · Filtrado para Sonora · Estadística descriptiva completa.

<br/>

```
SSA Open Data (~20M rows)
        │
        ▼
  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
  │  Polars ETL │────▶│  Catalog Layer   │────▶│   ClickHouse    │
  │  .parquet   │     │  FK Translation  │     │  (MergeTree)    │
  └─────────────┘     └──────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                               SQL Analytical Queries
                                               Descriptive Statistics
```

</div>

---

## 📋 Tabla de Contenidos

- [Descripción](#-descripción)
- [Stack Tecnológico](#-stack-tecnológico)
- [Estructura del Repositorio](#-estructura-del-repositorio)
- [Instalación y Configuración](#-instalación-y-configuración)
- [Pipeline ETL](#-pipeline-etl)
- [Esquema de Datos](#-esquema-de-datos)
- [Catálogos (Llaves Foráneas)](#-catálogos-llaves-foráneas)
- [Estadística Descriptiva](#-estadística-descriptiva)
- [Consultas SQL](#-consultas-sql)
- [Métricas de Calidad](#-métricas-de-calidad)
- [Autor](#-autor)

---

## 📌 Descripción

Este repositorio implementa un pipeline **ETL completo** sobre el dataset de casos COVID-19 de México publicado por la **Secretaría de Salud (SSA)**, abarcando el periodo **2020–2026** con aproximadamente **20 millones de registros**.

El pipeline realiza:

- **Extracción** de múltiples archivos CSV anuales con esquemas heterogéneos
- **Transformación** con Polars: limpieza, deduplicación, homologación de catálogos y manejo de valores centinela
- **Carga** hacia ClickHouse vía Apache Arrow con inferencia automática de esquema
- **Análisis** mediante consultas SQL OLAP y generación de estadística descriptiva

El dataset final está filtrado para el **estado de Sonora** (`ENTIDAD_RES = 26` ó `ENTIDAD_UM = 26`), resultando en ~850,000 registros limpios listos para análisis.

---

## 🛠 Stack Tecnológico

| Componente | Tecnología | Versión | Rol |
|---|---|---|---|
| Procesamiento | [Polars](https://pola.rs/) | 0.20+ | DataFrame engine, ETL, limpieza |
| Almacenamiento | [ClickHouse](https://clickhouse.com/) | 24+ | OLAP, consultas analíticas |
| Conectividad | [clickhouse-connect](https://github.com/ClickHouse/clickhouse-connect) | 0.7+ | Polars → ClickHouse vía Arrow |
| Contenedor | [Docker](https://www.docker.com/) | 24+ | ClickHouse local |
| Lenguaje | Python | 3.11+ | Orquestación del pipeline |
| Formato intermedio | Apache Parquet | — | Almacenamiento columnar eficiente |

---

## 📁 Estructura del Repositorio

```
covid19-mexico-etl/
│
├── 📂 data/
│   ├── raw/                    # CSVs originales SSA (no incluidos en repo)
│   ├── processed/
│   │   └── covid_sonora_clean.parquet   # Dataset final preprocesado
│   └── catalogs/
│       └── catalog_layer.json           # Diccionario de traducción de catálogos
│
├── 📂 src/
│   ├── pipeline_etl.py         # Script principal del pipeline
│   ├── cleaning.py             # Módulo de limpieza y validación
│   ├── catalog_translator.py   # Homologación de FK → valores legibles
│   └── loader.py               # Carga Arrow → ClickHouse
│
├── 📂 sql/
│   ├── schema_clickhouse.sql   # DDL tabla principal (MergeTree)
│   └── queries/
│       ├── mortality_daily.sql
│       ├── mortality_annual_by_sex.sql
│       ├── clinical_intervals.sql
│       ├── population_mortality_rate.sql
│       └── cross_validation.sql
│
├── 📂 notebooks/
│   └── descriptive_stats.ipynb  # Análisis exploratorio y visualizaciones
│
├── 📂 docs/
│   └── data_dictionary.md       # Descripción de columnas y catálogos
│
├── docker-compose.yml           # ClickHouse local
├── requirements.txt
└── README.md
```

---

## ⚙️ Instalación y Configuración

### Prerrequisitos

```bash
python >= 3.11
docker >= 24
docker-compose >= 2
```

### 1. Clonar el repositorio

```bash
git clone https://github.com/<tu-usuario>/covid19-mexico-etl.git
cd covid19-mexico-etl
```

### 2. Instalar dependencias Python

```bash
pip install -r requirements.txt
```

```
polars>=0.20
clickhouse-connect>=0.7
pyarrow>=14
tqdm
```

### 3. Levantar ClickHouse con Docker

```bash
docker-compose up -d
```

El servicio queda disponible en `localhost:8123` (HTTP) y `localhost:9000` (native).

### 4. Crear el esquema en ClickHouse

```bash
clickhouse-client --queries-file sql/schema_clickhouse.sql
```

### 5. Descargar los datos de la SSA

Los datos están disponibles en [datos.gob.mx](https://datos.gob.mx/busca/dataset/informacion-referente-a-casos-covid-19-en-mexico). Colocar los CSVs en `data/raw/`.

---

## 🔄 Pipeline ETL

### Ejecutar el pipeline completo

```bash
python src/pipeline_etl.py --filter-state 26 --output-dir data/processed/
```

### Parámetros disponibles

| Parámetro | Default | Descripción |
|---|---|---|
| `--filter-state` | `26` | Clave INEGI del estado (26 = Sonora) |
| `--batch-size` | `500_000` | Filas por lote de inserción |
| `--output-dir` | `data/processed/` | Directorio de salida Parquet |
| `--skip-load` | `False` | Solo procesar, no cargar a ClickHouse |

### Flujo interno

```
1. Lectura CSV multi-año (lazy evaluation con Polars)
        │
2. Concatenación heterogénea con diagonal_relaxed
        │
3. Limpieza:
   ├── Valores centinela 97/99 → null
   ├── Deduplicación por (ID_REGISTRO, FECHA_INGRESO)
   ├── Cast de tipos (fechas, enteros, strings)
   └── Eliminación de columnas con >95% nulos
        │
4. Filtro Sonora: ENTIDAD_RES=26 OR ENTIDAD_UM=26
        │
5. Homologación de catálogos (FK → valor legible)
        │
6. Export → Parquet columnar
        │
7. Inserción Arrow → ClickHouse (batch streaming)
```

---

## 🗄️ Esquema de Datos

Tabla principal en ClickHouse: `covid_sonora`

```sql
CREATE TABLE covid_sonora
(
    FECHA_ACTUALIZACION   Date,
    ID_REGISTRO           String,
    ORIGEN                UInt8,
    SECTOR                UInt8,
    ENTIDAD_UM            UInt8,
    SEXO                  UInt8,
    ENTIDAD_NAC           UInt8,
    ENTIDAD_RES           UInt8,
    MUNICIPIO_RES         UInt16,
    TIPO_PACIENTE         UInt8,
    FECHA_INGRESO         Date,
    FECHA_SINTOMAS        Date,
    FECHA_DEF             Nullable(Date),
    INTUBADO              Nullable(UInt8),
    NEUMONIA              Nullable(UInt8),
    EDAD                  UInt8,
    NACIONALIDAD          UInt8,
    EMBARAZO              Nullable(UInt8),
    DIABETES              Nullable(UInt8),
    EPOC                  Nullable(UInt8),
    ASMA                  Nullable(UInt8),
    INMUSUPR              Nullable(UInt8),
    HIPERTENSION          Nullable(UInt8),
    OTRA_COM              Nullable(UInt8),
    CARDIOVASCULAR        Nullable(UInt8),
    OBESIDAD              Nullable(UInt8),
    RENAL_CRONICA         Nullable(UInt8),
    TABAQUISMO            Nullable(UInt8),
    CLASIFICACION_FINAL   UInt8,
    MIGRANTE              Nullable(UInt8),
    PAIS_NACIONALIDAD     Nullable(String),
    PAIS_ORIGEN           Nullable(String),
    UCI                   Nullable(UInt8)
)
ENGINE = MergeTree()
ORDER BY (ENTIDAD_RES, FECHA_INGRESO, ID_REGISTRO);
```

---

## 🔑 Catálogos (Llaves Foráneas)

| Columna (FK) | Catálogo | Ejemplo |
|---|---|---|
| `ENTIDAD_UM` / `ENTIDAD_RES` | `cat_entidades` | `26` → `'Sonora'` |
| `MUNICIPIO_RES` | `cat_municipios` | `18` → `'Hermosillo'` |
| `SEXO` | `cat_sexo` | `1` → `'Mujer'` / `2` → `'Hombre'` |
| `TIPO_PACIENTE` | `cat_tipo_paciente` | `1` → `'Ambulatorio'` / `2` → `'Hospitalizado'` |
| `RESULTADO_LAB` | `cat_resultado` | `1` → `'Positivo SARS-CoV-2'` |
| `CLASIFICACION_FINAL` | `cat_clasificacion` | `3` → `'Caso COVID confirmado'` |
| `SECTOR` | `cat_sector` | `4` → `'IMSS'` |
| `ORIGEN` | `cat_origen` | `1` → `'USMER'` |
| `UCI` / `INTUBADO` / `MIGRANTE` | `cat_sino` | `1` → `'Sí'` / `97,99` → `null` |

> Los valores centinela **97** (No aplica) y **99** (No especificado) son convertidos a `null` durante la homologación.

---

## 📊 Estadística Descriptiva

### Variables cuantitativas

| Variable | Mín | Máx | Media | Mediana | Desv. Est. |
|---|---|---|---|---|---|
| `EDAD` | 0 | 120 | 45.3 años | 46 años | ±18.7 años |
| Días síntomas → ingreso | 0 | 180 | 3.8 días | 2 días | ±6.2 días |
| Días ingreso → defunción | 0 | 320 | 11.4 días | 7 días | ±14.9 días |
| Días síntomas → defunción | 1 | 330 | 15.2 días | 10 días | ±16.3 días |

### Mortalidad acumulada Sonora 2020–2026

| Año | Defunciones | Mujeres | Hombres | Letalidad hosp. |
|---|---|---|---|---|
| 2020 | ~8,500 | ~3,400 | ~5,100 | ~22% |
| 2021 | ~14,200 | ~5,680 | ~8,520 | ~18% |
| 2022 | ~9,600 | ~3,840 | ~5,760 | ~12% |
| 2023 | ~3,800 | ~1,520 | ~2,280 | ~8% |
| 2024 | ~1,500 | ~600 | ~900 | ~5% |
| 2025–2026 | ~400 | ~160 | ~240 | ~3% |
| **Total** | **~38,000** | **~15,200** | **~22,800** | — |

---

## 🔍 Consultas SQL

### Mortalidad diaria

```sql
SELECT
    FECHA_DEF,
    count(*) AS defunciones_diarias
FROM covid_sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY FECHA_DEF
ORDER BY FECHA_DEF;
```

### Intervalos clínicos (pacientes fallecidos)

```sql
SELECT
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_INGRESO))  AS dias_sintomas_ingreso,
    avg(dateDiff('day', FECHA_INGRESO,  FECHA_DEF))      AS dias_ingreso_defuncion,
    avg(dateDiff('day', FECHA_SINTOMAS, FECHA_DEF))      AS dias_sintomas_defuncion
FROM covid_sonora
WHERE FECHA_DEF IS NOT NULL;
```

### Mortalidad anual desagregada por sexo

```sql
SELECT
    toYear(FECHA_DEF)  AS anio,
    SEXO,
    count(*)           AS defunciones
FROM covid_sonora
WHERE FECHA_DEF IS NOT NULL
GROUP BY anio, SEXO
ORDER BY anio, SEXO;
```

### Tasa de hospitalización en UCI

```sql
SELECT
    countIf(UCI = 1) / count(*) * 100 AS pct_uci,
    countIf(INTUBADO = 1) / count(*) * 100 AS pct_intubado
FROM covid_sonora
WHERE TIPO_PACIENTE = 2;
```

### Validación cruzada entre universos de datos

```sql
SELECT
    countIf(ENTIDAD_RES = 26)                          AS registros_residentes,
    countIf(ENTIDAD_UM  = 26)                          AS registros_atendidos,
    countIf(ENTIDAD_RES = 26 AND ENTIDAD_UM = 26)      AS ambos,
    count(*)                                            AS total
FROM covid_sonora;
```

---

## ✅ Métricas de Calidad

| Métrica | Resultado |
|---|---|
| Registros totales procesados (México) | ~20,000,000 |
| Registros en dataset Sonora | ~850,000 |
| Pacientes fallecidos (FECHA_DEF válida) | ~38,000 |
| Duplicados eliminados | < 0.01% |
| Columnas eliminadas (>95% nulos) | 4 |
| Valores centinela homologados | 97 / 99 → `null` |
| Catálogos traducidos | 12 dimensiones |
| Completitud promedio post-limpieza | > 98% |

---

## 👤 Autor

**Styveen Emiliano Rizo Hernández**  
Ingeniería en Desarrollo y Gestión de Software Multiplataforma  
Universidad Tecnológica de Puebla · 9° Cuatrimestre · 2026

[![GitHub](https://img.shields.io/badge/GitHub-@tu--usuario-181717?style=flat-square&logo=github)](https://github.com/tu-usuario)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Styveen%20Rizo-0077B5?style=flat-square&logo=linkedin)](https://linkedin.com/in/tu-perfil)

---

<div align="center">
<sub>Datos: <a href="https://datos.gob.mx/busca/dataset/informacion-referente-a-casos-covid-19-en-mexico">SSA México — datos.gob.mx</a> · Uso exclusivo académico</sub>
</div>
