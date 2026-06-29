#!/usr/bin/env bash
# =============================================================================
# Step 5 - AWS Glue ETL Job 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

GLUE_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_GLUE_ROLE}"
GLUE_SCRIPT_KEY="glue/etl_job.py"
GLUE_SCRIPT_S3="s3://${S3_SCRIPTS_BUCKET}/${GLUE_SCRIPT_KEY}"

# ── Glue ETL 스크립트 업로드 ──────────────────────────────────────────────────
log "Glue ETL 스크립트 업로드 중..."

GLUE_SCRIPT_FILE=$(mktemp --suffix=.py)
cat > "$GLUE_SCRIPT_FILE" << 'PYEOF'
import sys
import boto3
from datetime import datetime, timedelta
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import *

args = getResolvedOptions(sys.argv, [
    'JOB_NAME', 'S3_RAW_BUCKET', 'S3_PROCESSED_BUCKET', 'TARGET_DATE'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

raw_bucket       = args['S3_RAW_BUCKET']
processed_bucket = args['S3_PROCESSED_BUCKET']
target_date      = args.get('TARGET_DATE', datetime.now().strftime('%Y-%m-%d'))

# Raw 데이터 로드
df = spark.read.option("header", True).option("inferSchema", True) \
    .csv(f"s3://{raw_bucket}/daily/{target_date}/")

# 정제: 결측값 처리 / 컬럼 표준화 / 기술 지표 계산
df = df.dropna(subset=["close", "volume", "ticker"]) \
       .withColumn("date", F.to_date("date", "yyyy-MM-dd")) \
       .withColumn("close",  F.col("close").cast(DoubleType())) \
       .withColumn("open",   F.col("open").cast(DoubleType())) \
       .withColumn("high",   F.col("high").cast(DoubleType())) \
       .withColumn("low",    F.col("low").cast(DoubleType())) \
       .withColumn("volume", F.col("volume").cast(LongType()))

# 이동평균 (5일, 20일) - 윈도우 함수 사용
from pyspark.sql.window import Window
w5  = Window.partitionBy("ticker").orderBy("date").rowsBetween(-4, 0)
w20 = Window.partitionBy("ticker").orderBy("date").rowsBetween(-19, 0)

df = df.withColumn("ma5",  F.avg("close").over(w5)) \
       .withColumn("ma20", F.avg("close").over(w20)) \
       .withColumn("vol_change", F.col("volume") / F.lag("volume", 1).over(
           Window.partitionBy("ticker").orderBy("date"))) \
       .withColumn("processed_at", F.current_timestamp())

# Parquet으로 저장 (파티셔닝)
df.write.mode("overwrite") \
    .partitionBy("date", "ticker") \
    .parquet(f"s3://{processed_bucket}/daily/")

job.commit()
PYEOF

aws s3 cp "$GLUE_SCRIPT_FILE" "$GLUE_SCRIPT_S3" > /dev/null
rm -f "$GLUE_SCRIPT_FILE"
ok "Glue 스크립트 업로드: $GLUE_SCRIPT_S3"

# ── Glue Database 생성 ────────────────────────────────────────────────────────
log "Glue 카탈로그 DB 생성 중: $GLUE_DATABASE"
aws glue create-database \
  --database-input "{\"Name\": \"${GLUE_DATABASE}\", \"Description\": \"Stock pipeline data catalog\"}" \
  --region "$AWS_REGION" 2>/dev/null || ok "Glue DB 이미 존재: $GLUE_DATABASE"

# ── Glue Job 생성 ─────────────────────────────────────────────────────────────
log "Glue ETL 작업 생성 중: $GLUE_JOB"

if aws glue get-job --job-name "$GLUE_JOB" --region "$AWS_REGION" > /dev/null 2>&1; then
  ok "Glue 작업 이미 존재: $GLUE_JOB"
else
  aws glue create-job \
    --name "$GLUE_JOB" \
    --role "$GLUE_ROLE_ARN" \
    --command "{
      \"Name\": \"glueetl\",
      \"ScriptLocation\": \"${GLUE_SCRIPT_S3}\",
      \"PythonVersion\": \"3\"
    }" \
    --default-arguments "{
      \"--job-language\":        \"python\",
      \"--TempDir\":             \"s3://${S3_SCRIPTS_BUCKET}/glue/tmp/\",
      \"--enable-metrics\":      \"\",
      \"--enable-spark-ui\":     \"true\",
      \"--spark-event-logs-path\": \"s3://${S3_SCRIPTS_BUCKET}/glue/spark-logs/\",
      \"--S3_RAW_BUCKET\":       \"${S3_RAW_BUCKET}\",
      \"--S3_PROCESSED_BUCKET\": \"${S3_PROCESSED_BUCKET}\"
    }" \
    --glue-version "4.0" \
    --number-of-workers 2 \
    --worker-type "G.1X" \
    --timeout 60 \
    --tags Project="$PROJECT",Env="$ENV" \
    --region "$AWS_REGION" \
    > /dev/null

  ok "Glue 작업 생성 완료: $GLUE_JOB"
fi
