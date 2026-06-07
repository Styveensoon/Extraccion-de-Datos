import polars as pl
import clickhouse_connect
from pathlib import Path
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────

DATA_DIR   = Path("./data_lote2")
BACKUP_DIR = Path("./data/backup_lote2")
BACKUP_DIR.mkdir(exist_ok=True)

DB    = "covid_mx_lote2"
TABLE = "sonora"
FULL  = f"{DB}.{TABLE}"

ARCHIVOS = [
    "COVID19MEXICO 2020.csv",
    "COVID19MEXICO 2021.csv",
    "COVID19MEXICO 2022.csv",
    "COVID19MEXICO 2023.csv",
    "COVID19MEXICO 2024.csv",
    "COVID19MEXICO 2025.csv",
    "COVID19MEXICO 2026.csv",
]

SCHEMA_OVERRIDES = {
    "PAIS_ORIGEN":          pl.Utf8,
    "PAIS_NACIONALIDAD":    pl.Utf8,
    "MUNICIPIO_RES":        pl.Utf8,
    "MUNICIPIO_NACIMIENTO": pl.Utf8,
}

# ─────────────────────────────────────────────
# CATÁLOGOS
# ─────────────────────────────────────────────

CAT_ORIGEN = {1: "USMER", 2: "FUERA DE USMER", 99: "NO ESPECIFICADO"}

CAT_SECTOR = {
    1: "CRUZ ROJA", 2: "DIF", 3: "ESTATAL", 4: "IMSS",
    5: "IMSS-BIENESTAR", 6: "ISSSTE", 7: "MUNICIPAL", 8: "PEMEX",
    9: "PRIVADA", 10: "SEDENA", 11: "SEMAR", 12: "SSA",
    13: "UNIVERSITARIO", 14: "CIJ", 15: "IMSS BIENESTAR OPD",
    99: "NO ESPECIFICADO",
}

CAT_SEXO          = {1: "MUJER", 2: "HOMBRE", 99: "NO ESPECIFICADO"}
CAT_TIPO_PACIENTE = {1: "AMBULATORIO", 2: "HOSPITALIZADO", 99: "NO ESPECIFICADO"}

CAT_SI_NO = {
    1: "SI", 2: "NO", 97: "NO APLICA", 98: "SE IGNORA", 99: "NO ESPECIFICADO"
}

CAT_NACIONALIDAD = {1: "MEXICANA", 2: "EXTRANJERA", 99: "NO ESPECIFICADO"}

CAT_RESULTADO_LAB = {
    1: "POSITIVO A SARS-COV-2", 2: "NO POSITIVO A SARS-COV-2",
    3: "RESULTADO PENDIENTE",   4: "RESULTADO NO ADECUADO",
    97: "NO APLICA (CASO SIN MUESTRA)",
}

CAT_RESULTADO_ANTIGENO = {
    1: "POSITIVO A SARS-COV-2", 2: "NEGATIVO A SARS-COV-2",
    97: "NO APLICA (CASO SIN MUESTRA)",
}

CAT_RESULTADO_PCR = {
    1: "INFLUENZA AH1N1 PMD", 2: "INFLUENZA A H1", 3: "INFLUENZA A H3",
    4: "INFLUENZA B", 5: "NEGATIVO", 6: "MUESTRA NO ADECUADA",
    7: "ADENOVIRUS", 8: "PARAINFLUENZA 1", 9: "PARAINFLUENZA 2",
    10: "PARAINFLUENZA 3", 11: "VIRUS SINCICIAL RESPIRATORIO",
    13: "INFLUENZA A NO SUBTIPIFICADA", 14: "INFLUENZA A H5",
    17: "MUESTRA RECHAZADA", 20: "VIRUS SINCICIAL RESPIRATORIO A",
    21: "VIRUS SINCICIAL RESPIRATORIO B", 22: "CORONA 229E",
    23: "CORONA OC43", 24: "CORONA SARS", 25: "CORONA NL63",
    26: "CORONA HKU1", 27: "MUESTRA QUE NO AMPLIFICO",
    28: "ENTEROV/RHINOVIRUS", 29: "METAPNEUMOVIRUS",
    30: "MUESTRA SIN AISLAMIENTO", 32: "PARAINFLUENZA 4",
    33: "MUESTRA SIN CELULAS", 34: "SARS-CoV-2", 35: "MERS-CoV",
    36: "SARS-CoV", 37: "BOCAVIRUS", 41: "MUESTRA NO RECIBIDA",
    997: "NO APLICA (CASO SIN MUESTRA)", 998: "SIN COINFECCIÓN", 999: "PENDIENTE",
}

CAT_CLASIFICACION_COVID = {
    1: "CONFIRMADO POR ASOCIACIÓN CLÍNICA EPIDEMIOLÓGICA",
    2: "CONFIRMADO POR COMITÉ DE DICTAMINACIÓN",
    3: "CASO DE SARS-COV-2 CONFIRMADO",
    4: "INVÁLIDO POR LABORATORIO",
    5: "NO REALIZADO POR LABORATORIO",
    6: "CASO SOSPECHOSO",
    7: "NEGATIVO A SARS-COV-2",
}

CAT_ENTIDADES = {
    1: "AGUASCALIENTES", 2: "BAJA CALIFORNIA", 3: "BAJA CALIFORNIA SUR",
    4: "CAMPECHE", 5: "COAHUILA DE ZARAGOZA", 6: "COLIMA", 7: "CHIAPAS",
    8: "CHIHUAHUA", 9: "CIUDAD DE MÉXICO", 10: "DURANGO", 11: "GUANAJUATO",
    12: "GUERRERO", 13: "HIDALGO", 14: "JALISCO", 15: "MÉXICO",
    16: "MICHOACÁN DE OCAMPO", 17: "MORELOS", 18: "NAYARIT", 19: "NUEVO LEÓN",
    20: "OAXACA", 21: "PUEBLA", 22: "QUERÉTARO", 23: "QUINTANA ROO",
    24: "SAN LUIS POTOSÍ", 25: "SINALOA", 26: "SONORA", 27: "TABASCO",
    28: "TAMAULIPAS", 29: "TLAXCALA", 30: "VERACRUZ DE IGNACIO DE LA LLAVE",
    31: "YUCATÁN", 32: "ZACATECAS", 36: "ESTADOS UNIDOS MEXICANOS",
    97: "NO APLICA", 98: "SE IGNORA", 99: "NO ESPECIFICADO",
}

COLS_SI_NO = [
    "INTUBADO", "NEUMONIA", "EMBARAZO", "HABLA_LENGUA_INDIG", "INDIGENA",
    "DIABETES", "EPOC", "ASMA", "INMUSUPR", "HIPERTENSION", "OTRA_COM",
    "CARDIOVASCULAR", "OBESIDAD", "RENAL_CRONICA", "TABAQUISMO", "OTRO_CASO",
    "TOMA_MUESTRA_LAB", "POTENCIAL_DEFUNCION", "TOMA_MUESTRA_ANTIGENO",
    "MIGRANTE",
]

COLS_ENTIDAD = ["ENTIDAD_UM", "ENTIDAD_NAC", "ENTIDAD_RES"]

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def map_col(df: pl.DataFrame, col: str, mapping: dict) -> pl.DataFrame:
    if col not in df.columns:
        return df
    expr = pl.lit(None, dtype=pl.Utf8)
    for k, v in mapping.items():
        expr = pl.when(pl.col(col) == k).then(pl.lit(v)).otherwise(expr)
    return df.with_columns(expr.alias(col))


def aplicar_catalogos(df: pl.DataFrame) -> pl.DataFrame:
    df = map_col(df, "ORIGEN",              CAT_ORIGEN)
    df = map_col(df, "SECTOR",              CAT_SECTOR)
    df = map_col(df, "SEXO",                CAT_SEXO)
    df = map_col(df, "TIPO_PACIENTE",       CAT_TIPO_PACIENTE)
    df = map_col(df, "NACIONALIDAD",        CAT_NACIONALIDAD)
    df = map_col(df, "RESULTADO_LAB",       CAT_RESULTADO_LAB)
    df = map_col(df, "RESULTADO_ANTIGENO",  CAT_RESULTADO_ANTIGENO)
    df = map_col(df, "RESULTADO_PCR",       CAT_RESULTADO_PCR)
    df = map_col(df, "CLASIFICACION_FINAL", CAT_CLASIFICACION_COVID)
    for col in COLS_SI_NO:
        df = map_col(df, col, CAT_SI_NO)
    for col in COLS_ENTIDAD:
        df = map_col(df, col, CAT_ENTIDADES)
    return df


def polars_to_ch_type(dtype) -> str:
    if dtype == pl.Date:                        return "Nullable(Date)"
    if dtype in (pl.Int8, pl.Int16, pl.Int32):  return "Nullable(Int32)"
    if dtype == pl.Int64:                       return "Nullable(Int64)"
    if dtype == pl.Float32:                     return "Nullable(Float32)"
    if dtype == pl.Float64:                     return "Nullable(Float64)"
    return "Nullable(String)"

# ─────────────────────────────────────────────
# PASO 1 — CARGA Y TRANSFORMACIÓN
# ─────────────────────────────────────────────

print("📂 Cargando archivos CSV...")
dataframes = []

for archivo in ARCHIVOS:
    ruta = DATA_DIR / archivo
    if ruta.exists():
        df = pl.scan_csv(
            ruta,
            encoding="utf8-lossy",
            null_values=["", "99", "9999-99-99"],
            try_parse_dates=True,
            infer_schema_length=10000,
            schema_overrides=SCHEMA_OVERRIDES,
            ignore_errors=True,
        )
        dataframes.append(df)
        print(f"  ✅ {archivo}")
    else:
        print(f"  ⚠️  No encontrado: {archivo}")

covid_df  = pl.concat(dataframes, how="diagonal_relaxed").collect()

print("\n🔍 Filtrando Sonora...")
df_sonora_raw = (
    covid_df
    .filter(
        (pl.col("ENTIDAD_RES") == 26) |
        (pl.col("ENTIDAD_NAC") == 26) |
        (pl.col("ENTIDAD_UM")  == 26)
    )
    .unique()
)

print("🏷️  Aplicando catálogos...")
df_sonora = aplicar_catalogos(df_sonora_raw)

print(f"\n📊 Shape final: {df_sonora.shape[0]:,} filas × {df_sonora.shape[1]} cols")

# ─────────────────────────────────────────────
# PASO 2 — BACKUP CSV  (siempre, sin importar lo que decidas después)
# ─────────────────────────────────────────────

ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
csv_path = BACKUP_DIR / f"backup_sonora_{ts}.csv"
print(f"\n💾 Guardando backup → {csv_path} ...")
df_sonora.write_csv(csv_path)
print(f"   ✅ Backup listo: {df_sonora.shape[0]:,} filas")

# ─────────────────────────────────────────────
# PASO 3 — CONFIRMACIÓN ANTES DE TOCAR CLICKHOUSE
# ─────────────────────────────────────────────

print("\n" + "="*50)
print(f"  Backup guardado en: {csv_path}")
print(f"  Filas listas para cargar: {df_sonora.shape[0]:,}")
print("="*50)

while True:
    respuesta = input("\n¿Proceder con la carga a ClickHouse? [Y/N]: ").strip().upper()
    if respuesta in ("Y", "N"):
        break
    print("  ⚠️  Escribe Y o N")

if respuesta == "N":
    print("\n🔒 Carga cancelada. Backup conservado, ClickHouse no fue tocado.")
    raise SystemExit(0)

# ─────────────────────────────────────────────
# PASO 4 — CLICKHOUSE  (solo llega aquí si dijiste Y)
# ─────────────────────────────────────────────

print("\n🔌 Conectando a ClickHouse...")
client = clickhouse_connect.get_client(
    host="localhost", port=8123,
    username="polars", password="Polars21"
)

client.command(f"CREATE DATABASE IF NOT EXISTS {DB}")

table_exists = int(client.command(f"""
    SELECT count() FROM system.tables
    WHERE database = '{DB}' AND name = '{TABLE}'
""")) > 0

if table_exists:
    row_count = int(client.command(f"SELECT count() FROM {FULL}"))
    if row_count > 0:
        print(f"⚠️  '{FULL}' ya tiene {row_count:,} filas → truncando...")
        client.command(f"TRUNCATE TABLE {FULL}")

cols_ddl = ",\n  ".join(
    f"`{col}` {polars_to_ch_type(dtype)}"
    for col, dtype in zip(df_sonora.columns, df_sonora.dtypes)
)

client.command(f"""
    CREATE TABLE IF NOT EXISTS {FULL} (
      {cols_ddl}
    ) ENGINE = MergeTree()
    ORDER BY tuple()
""")

print(f"⬆️  Insertando {df_sonora.shape[0]:,} filas en {FULL}...")
client.insert_arrow(FULL, df_sonora.to_arrow())
print(f"✅ Listo — {FULL} cargada con {df_sonora.shape[0]:,} filas")