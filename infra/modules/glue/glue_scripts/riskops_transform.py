"""
riskops_transform.py — Glue ETL job.

Reads raw RiskOps transaction events (GZIP JSON landed by Firehose) from the
raw/ prefix, cleans and enriches them, and writes the curated result as
partitioned Parquet to the refined/ prefix.

The job runs incrementally: Glue job bookmarks track which raw files have
already been processed, so each run only picks up newly landed data.

Job arguments (supplied by Terraform):
  --JOB_NAME      Glue job name (provided automatically by Glue).
  --source_path   s3:// path to the raw events.
  --target_path   s3:// path for the refined Parquet output.
"""

import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import (
    BooleanType,
    DoubleType,
    LongType,
    StringType,
    StructField,
    StructType,
)

# --------------------------------------------------------------------------- #
# Bootstrap
# --------------------------------------------------------------------------- #
args = getResolvedOptions(sys.argv, ["JOB_NAME", "source_path", "target_path"])

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

SOURCE_PATH = args["source_path"]
TARGET_PATH = args["target_path"]

# Explicit schema — never trust inference for a curated layer. Mirrors the
# event produced by data_generation_kafka_producer.py.
RAW_SCHEMA = StructType(
    [
        StructField("transaction_id", LongType(), True),
        StructField("account_id", LongType(), True),
        StructField("customer_id", LongType(), True),
        StructField("amount", DoubleType(), True),
        StructField("currency", StringType(), True),
        StructField("transaction_type", StringType(), True),
        StructField("channel", StringType(), True),
        StructField("account_type", StringType(), True),
        StructField("origin_country", StringType(), True),
        StructField("destination_country", StringType(), True),
        StructField("risk_category", StringType(), True),
        StructField("risk_score", DoubleType(), True),
        StructField("is_flagged", BooleanType(), True),
        StructField("event_time", StringType(), True),
    ]
)


# --------------------------------------------------------------------------- #
# Extract — read only new files (bookmarks) via the Glue data source.
# --------------------------------------------------------------------------- #
raw_dyf = glue_context.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={
        "paths": [SOURCE_PATH],
        "recurse": True,
        # Honour Glue job bookmarks so already-processed files are skipped.
        "groupFiles": "inPartition",
    },
    format="json",
    format_options={"compression": "gzip"},
    transformation_ctx="raw_dyf",
)

# Nothing new this run — exit cleanly so the bookmark still advances.
if raw_dyf.count() == 0:
    job.commit()
    sys.exit(0)

# Resolve any ambiguous types, then move to a DataFrame for the transforms.
raw_dyf = raw_dyf.resolveChoice(choice="make_struct")
df = raw_dyf.toDF()

# Enforce the expected schema/column set: select known columns, cast to types.
df = df.select(
    *[
        F.col(field.name).cast(field.dataType).alias(field.name)
        for field in RAW_SCHEMA.fields
        if field.name in df.columns
    ]
)


# --------------------------------------------------------------------------- #
# Transform — clean, dedup, enrich, partition.
# --------------------------------------------------------------------------- #
# Parse the ISO-8601 event_time string into a real timestamp.
df = df.withColumn("event_time", F.to_timestamp("event_time"))

# Drop records without the key fields we partition / dedup on.
df = df.filter(F.col("transaction_id").isNotNull() & F.col("event_time").isNotNull())

# Normalise categorical codes.
df = (
    df.withColumn("currency", F.upper(F.trim(F.col("currency"))))
    .withColumn("origin_country", F.upper(F.trim(F.col("origin_country"))))
    .withColumn("destination_country", F.upper(F.trim(F.col("destination_country"))))
)

# Deduplicate on transaction_id, keeping the latest event_time.
df = (
    df.withColumn(
        "_rn",
        F.row_number().over(
            Window.partitionBy("transaction_id").orderBy(F.col("event_time").desc())
        ),
    )
    .filter(F.col("_rn") == 1)
    .drop("_rn")
)

# Derived columns.
df = (
    df.withColumn(
        "risk_level",
        F.when(F.col("risk_score") >= 80, F.lit("high"))
        .when(F.col("risk_score") >= 50, F.lit("medium"))
        .otherwise(F.lit("low")),
    )
    .withColumn(
        "is_cross_border",
        F.col("origin_country") != F.col("destination_country"),
    )
    # Partition columns derived from event time.
    .withColumn("year", F.date_format("event_time", "yyyy"))
    .withColumn("month", F.date_format("event_time", "MM"))
    .withColumn("day", F.date_format("event_time", "dd"))
)


# --------------------------------------------------------------------------- #
# Load — append partitioned Parquet (Snappy) to the refined prefix.
# --------------------------------------------------------------------------- #
refined_dyf = DynamicFrame.fromDF(df, glue_context, "refined_dyf")

glue_context.write_dynamic_frame.from_options(
    frame=refined_dyf,
    connection_type="s3",
    connection_options={
        "path": TARGET_PATH,
        "partitionKeys": ["year", "month", "day"],
    },
    format="glueparquet",
    format_options={"compression": "snappy"},
    transformation_ctx="refined_sink",
)

job.commit()
