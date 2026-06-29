#!/usr/bin/env bash
# =============================================================================
# 전체 파이프라인 삭제 (역순)
# 사용법: ./destroy_all.sh [dev|prod]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ENV="${1:-dev}"

source "${SCRIPT_DIR}/00_config.sh"
require_aws

echo "================================================================"
echo "  ⚠  전체 리소스 삭제"
echo "  Account : $AWS_ACCOUNT_ID  /  Env : $ENV"
echo "================================================================"
read -r -p "정말 삭제하시겠습니까? (yes/no) : " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "취소됨."; exit 0; }

# EventBridge 삭제
log "EventBridge 스케줄 삭제..."
aws scheduler delete-schedule --name "$EVENTBRIDGE_RULE" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $EVENTBRIDGE_RULE" || true

# Step Functions 삭제
log "Step Functions 삭제..."
SFN_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:${SFN_STATE_MACHINE}"
aws stepfunctions delete-state-machine --state-machine-arn "$SFN_ARN" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $SFN_STATE_MACHINE" || true

# API Gateway 삭제
log "API Gateway 삭제..."
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='${APIGW_NAME}'].id" --output text --region "$AWS_REGION")
[[ -n "$API_ID" ]] && aws apigateway delete-rest-api --rest-api-id "$API_ID" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $APIGW_NAME ($API_ID)" || true

# Lambda 삭제
log "Lambda 삭제..."
aws lambda delete-function --function-name "$LAMBDA_FUNCTION" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $LAMBDA_FUNCTION" || true

# SageMaker Pipeline 삭제
log "SageMaker Pipeline 삭제..."
aws sagemaker delete-pipeline --pipeline-name "$SAGEMAKER_PIPELINE" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $SAGEMAKER_PIPELINE" || true

# Glue Job 삭제
log "Glue Job 삭제..."
aws glue delete-job --job-name "$GLUE_JOB" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $GLUE_JOB" || true
aws glue delete-database --name "$GLUE_DATABASE" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $GLUE_DATABASE" || true

# Batch 삭제
log "Batch 리소스 삭제..."
aws batch update-job-queue --job-queue "$BATCH_JOB_QUEUE" --state DISABLED --region "$AWS_REGION" 2>/dev/null || true
sleep 5
aws batch delete-job-queue --job-queue "$BATCH_JOB_QUEUE" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $BATCH_JOB_QUEUE" || true
aws batch update-compute-environment --compute-environment "$BATCH_COMPUTE_ENV" --state DISABLED --region "$AWS_REGION" 2>/dev/null || true
sleep 10
aws batch delete-compute-environment --compute-environment "$BATCH_COMPUTE_ENV" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $BATCH_COMPUTE_ENV" || true

# DynamoDB 삭제
log "DynamoDB 테이블 삭제..."
aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" 2>/dev/null && ok "삭제: $DYNAMODB_TABLE" || true

# S3 버킷 삭제 (객체 포함)
delete_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    aws s3 rm "s3://${bucket}" --recursive --quiet
    aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION"
    ok "삭제: s3://$bucket"
  fi
}

log "S3 버킷 삭제..."
delete_bucket "$S3_RAW_BUCKET"
delete_bucket "$S3_PROCESSED_BUCKET"
delete_bucket "$S3_SCRIPTS_BUCKET"

ok "전체 리소스 삭제 완료"
