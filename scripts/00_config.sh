#!/usr/bin/env bash
# =============================================================================
# 공통 설정 - 모든 스크립트에서 source 하여 사용
# =============================================================================

# ── 기본 설정 ─────────────────────────────────────────────────────────────────
export AWS_REGION="${AWS_REGION:-ap-northeast-2}"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"

# ── 프로젝트 네이밍 ────────────────────────────────────────────────────────────
export PROJECT="stock-pipeline"
export ENV="${ENV:-dev}"
export PREFIX="${PROJECT}-${ENV}"

# ── S3 버킷 ───────────────────────────────────────────────────────────────────
export S3_RAW_BUCKET="${PREFIX}-raw-${AWS_ACCOUNT_ID}"
export S3_PROCESSED_BUCKET="${PREFIX}-processed-${AWS_ACCOUNT_ID}"
export S3_SCRIPTS_BUCKET="${PREFIX}-scripts-${AWS_ACCOUNT_ID}"

# ── DynamoDB ──────────────────────────────────────────────────────────────────
export DYNAMODB_TABLE="${PREFIX}-analysis"

# ── IAM ───────────────────────────────────────────────────────────────────────
export IAM_BATCH_ROLE="${PREFIX}-batch-role"
export IAM_STEP_ROLE="${PREFIX}-stepfunctions-role"
export IAM_GLUE_ROLE="${PREFIX}-glue-role"
export IAM_SAGEMAKER_ROLE="${PREFIX}-sagemaker-role"
export IAM_LAMBDA_ROLE="${PREFIX}-lambda-role"
export IAM_EVENTBRIDGE_ROLE="${PREFIX}-eventbridge-role"

# ── Batch ─────────────────────────────────────────────────────────────────────
export BATCH_COMPUTE_ENV="${PREFIX}-compute-env"
export BATCH_JOB_QUEUE="${PREFIX}-job-queue"
export BATCH_JOB_DEF_COLLECT="${PREFIX}-collect-job"
export BATCH_JOB_DEF_REFINE="${PREFIX}-refine-job"
export ECR_REPO_COLLECT="${PREFIX}-collect"
export ECR_REPO_REFINE="${PREFIX}-refine"

# ── Glue ──────────────────────────────────────────────────────────────────────
export GLUE_JOB="${PREFIX}-etl-job"
export GLUE_DATABASE="${PREFIX//-/_}_db"

# ── SageMaker ─────────────────────────────────────────────────────────────────
export SAGEMAKER_PIPELINE="${PREFIX}-ml-pipeline"
export SAGEMAKER_ENDPOINT="${PREFIX}-endpoint"
export SAGEMAKER_MODEL="${PREFIX}-model"

# ── Lambda ────────────────────────────────────────────────────────────────────
export LAMBDA_FUNCTION="${PREFIX}-api-handler"

# ── API Gateway ───────────────────────────────────────────────────────────────
export APIGW_NAME="${PREFIX}-api"

# ── Step Functions ────────────────────────────────────────────────────────────
export SFN_STATE_MACHINE="${PREFIX}-workflow"

# ── EventBridge ───────────────────────────────────────────────────────────────
export EVENTBRIDGE_RULE="${PREFIX}-daily-trigger"
export EVENTBRIDGE_SCHEDULE="cron(0 7 * * ? *)"   # 매일 07:00 UTC = 16:00 KST

# ── 유틸 함수 ──────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $*" >&2; }
die()  { err "$*"; exit 1; }

require_aws() {
  aws sts get-caller-identity > /dev/null 2>&1 || die "AWS 자격증명이 설정되어 있지 않습니다."
  [[ -n "$AWS_ACCOUNT_ID" ]] || die "AWS Account ID를 가져올 수 없습니다."
}
