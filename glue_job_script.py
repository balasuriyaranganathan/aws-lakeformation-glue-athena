import sys
from pyspark.sql import SparkSession

# ----------------------------------------------------------------------
# Helper: fetch Glue arguments safely
# ----------------------------------------------------------------------
def get_arg(name, default=None):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default

# ----------------------------------------------------------------------
# Read arguments
# ----------------------------------------------------------------------
raw_bucket = "csv-to-iceberg-demo-raw-bucket"
raw_prefix = get_arg("--RAW_PREFIX", "raw/")
glue_db = get_arg("--GLUE_DB", "demo_iceberg_db")
table_name = get_arg("--ICEBERG_TABLE", "customers")

# ----------------------------------------------------------------------
# ✅ Hardcode warehouse path (MUST start with s3:// and end with /)
# ----------------------------------------------------------------------
warehouse_path = "<warehouse_path>"

target_path = f"{warehouse_path}{glue_db}/{table_name}/"

print("====================================================")
print("✅ Starting Glue Iceberg ETL Job")
print(f"   RAW_BUCKET:      {raw_bucket}")
print(f"   RAW_PREFIX:      {raw_prefix}")
print(f"   GLUE_DB:         {glue_db}")
print(f"   TABLE_NAME:      {table_name}")
print(f"   WAREHOUSE_PATH:  {warehouse_path}")
print(f"   TARGET_PATH:     {target_path}")
print("====================================================")

# ----------------------------------------------------------------------
# Initialize Spark with Glue + Iceberg Catalog configs
# ----------------------------------------------------------------------
spark = (
    SparkSession.builder
    .appName("CSV-to-Iceberg-ETL")
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.warehouse", warehouse_path)
    .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .getOrCreate()
)

# ----------------------------------------------------------------------
# Step 1: Read CSV from Raw Bucket
# ----------------------------------------------------------------------
input_path = f"s3://{raw_bucket}/{raw_prefix}"
print(f"📥 Reading CSV input from: {input_path}")

df = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(input_path)
)

record_count = df.count()
print(f"✅ Successfully read {record_count} records from CSV")

# ----------------------------------------------------------------------
# Step 2: Ensure Glue Database Exists
# ----------------------------------------------------------------------
spark.sql(f"CREATE DATABASE IF NOT EXISTS {glue_db}")
spark.sql(f"USE {glue_db}")

# ----------------------------------------------------------------------
# Step 3: Write to Iceberg Table (3-part identifier)
# ----------------------------------------------------------------------
print(f"🧊 Writing Iceberg table to: {target_path}")

(
    df.writeTo(f"glue_catalog.{glue_db}.{table_name}")  # ✅ use full catalog path
      .option("path", target_path)
      .using("iceberg")
      .tableProperty("format-version", "2")
      .createOrReplace()
)

print(f"✅ Iceberg table successfully created: glue_catalog.{glue_db}.{table_name}")

# ----------------------------------------------------------------------
# Step 4: Validate Read Back
# ----------------------------------------------------------------------
print("🔍 Reading back from Iceberg table...")
read_df = spark.read.table(f"glue_catalog.{glue_db}.{table_name}")
print(f"✅ Verified record count in Iceberg table: {read_df.count()}")
read_df.show(5)

print("====================================================")
print("🎉 Glue Iceberg ETL job completed successfully!")
print("====================================================")

spark.stop()
