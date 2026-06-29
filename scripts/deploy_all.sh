#!/usr/bin/env bash
# =============================================================================
# 전체 파이프라인 배포 (순서대로 실행)
# 사용법: ./deploy_all.sh [dev|prod]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ENV="${1:-dev}"

source "${SCRIPT_DIR}/00_config.sh"
require_aws

echo "================================================================"
echo "  Stock Pipeline 배포 시작"
echo "  Account  : $AWS_ACCOUNT_ID"
echo "  Region   : $AWS_REGION"
echo "  Env      : $ENV"
echo "  Prefix   : $PREFIX"
echo "================================================================"
echo ""

run_step() {
  local step_num="$1"
  local script="$2"
  local label="$3"

  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "  [Step ${step_num}] ${label}"
  echo "────────────────────────────────────────────────────────────────"
  bash "${SCRIPT_DIR}/${script}"
}

run_step "1" "01_iam.sh"           "IAM 역할 및 정책"
run_step "2" "02_s3.sh"            "S3 버킷 (Raw / Processed / Scripts)"
run_step "3" "03_dynamodb.sh"      "DynamoDB 테이블"
run_step "4" "04_batch.sh"         "AWS Batch (컴퓨팅 환경 / 작업 정의)"
run_step "5" "05_glue.sh"          "AWS Glue ETL Job"
run_step "6" "06_sagemaker.sh"     "Amazon SageMaker Pipeline"
run_step "7" "07_lambda_apigw.sh"  "Lambda + API Gateway"
run_step "8" "08_stepfunctions.sh" "Step Functions 워크플로우"
run_step "9" "09_eventbridge.sh"   "EventBridge 스케줄러"

echo ""
echo "================================================================"
ok "전체 파이프라인 배포 완료!"
echo ""
echo "  API Endpoint:"
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='${APIGW_NAME}'].id" --output text --region "$AWS_REGION")
echo "  https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${ENV}"
echo ""
echo "  수동 실행 (테스트):"
SFN_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:${SFN_STATE_MACHINE}"
echo "  aws stepfunctions start-execution \\"
echo "    --state-machine-arn ${SFN_ARN} \\"
echo "    --input '{\"target_date\":\"$(date +%Y-%m-%d)\"}'"
echo "================================================================"
