#!/usr/bin/env bash
# =============================================================================
# Step 4 - AWS Batch 환경 구성 (컴퓨팅 환경 / 작업 대기열 / 작업 정의)
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

BATCH_SERVICE_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PREFIX}-batch-service-role"
BATCH_JOB_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_BATCH_ROLE}"

# ── 기본 VPC / 서브넷 / 보안그룹 조회 ─────────────────────────────────────────
log "VPC 정보 조회 중..."
DEFAULT_VPC=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text --region "$AWS_REGION")

SUBNETS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$DEFAULT_VPC" \
  --query 'Subnets[*].SubnetId' --output text --region "$AWS_REGION" | tr '\t' ',')

DEFAULT_SG=$(aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values="$DEFAULT_VPC" Name=group-name,Values=default \
  --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION")

log "VPC: $DEFAULT_VPC / SG: $DEFAULT_SG"

# ── 컴퓨팅 환경 생성 ──────────────────────────────────────────────────────────
log "Batch 컴퓨팅 환경 생성 중: $BATCH_COMPUTE_ENV"

EXISTING_CE=$(aws batch describe-compute-environments \
  --compute-environments "$BATCH_COMPUTE_ENV" \
  --query 'computeEnvironments[0].status' --output text 2>/dev/null || echo "NONE")

if [[ "$EXISTING_CE" != "NONE" && "$EXISTING_CE" != "None" ]]; then
  ok "컴퓨팅 환경 이미 존재: $BATCH_COMPUTE_ENV"
else
  aws batch create-compute-environment \
    --compute-environment-name "$BATCH_COMPUTE_ENV" \
    --type MANAGED \
    --state ENABLED \
    --service-role "$BATCH_SERVICE_ROLE_ARN" \
    --compute-resources "{
      \"type\": \"FARGATE\",
      \"maxvCpus\": 16,
      \"subnets\": [\"${SUBNETS//,/\",\"}\"],
      \"securityGroupIds\": [\"${DEFAULT_SG}\"]
    }" \
    --region "$AWS_REGION" \
    > /dev/null

  log "컴퓨팅 환경 활성화 대기 중..."
  while true; do
    STATUS=$(aws batch describe-compute-environments \
      --compute-environments "$BATCH_COMPUTE_ENV" \
      --query 'computeEnvironments[0].status' --output text --region "$AWS_REGION")
    [[ "$STATUS" == "VALID" ]] && break
    sleep 5
  done
  ok "컴퓨팅 환경 생성 완료: $BATCH_COMPUTE_ENV"
fi

# ── 작업 대기열 생성 ──────────────────────────────────────────────────────────
log "Batch 작업 대기열 생성 중: $BATCH_JOB_QUEUE"

EXISTING_JQ=$(aws batch describe-job-queues \
  --job-queues "$BATCH_JOB_QUEUE" \
  --query 'jobQueues[0].status' --output text 2>/dev/null || echo "NONE")

if [[ "$EXISTING_JQ" != "NONE" && "$EXISTING_JQ" != "None" ]]; then
  ok "작업 대기열 이미 존재: $BATCH_JOB_QUEUE"
else
  aws batch create-job-queue \
    --job-queue-name "$BATCH_JOB_QUEUE" \
    --state ENABLED \
    --priority 100 \
    --compute-environment-order order=1,computeEnvironment="$BATCH_COMPUTE_ENV" \
    --region "$AWS_REGION" \
    > /dev/null

  log "작업 대기열 활성화 대기 중..."
  while true; do
    STATUS=$(aws batch describe-job-queues \
      --job-queues "$BATCH_JOB_QUEUE" \
      --query 'jobQueues[0].status' --output text --region "$AWS_REGION")
    [[ "$STATUS" == "VALID" ]] && break
    sleep 5
  done
  ok "작업 대기열 생성 완료: $BATCH_JOB_QUEUE"
fi

# ── 작업 정의: 데이터 수집 ────────────────────────────────────────────────────
log "Batch 작업 정의 등록: $BATCH_JOB_DEF_COLLECT (수집)"

aws batch register-job-definition \
  --job-definition-name "$BATCH_JOB_DEF_COLLECT" \
  --type container \
  --platform-capabilities FARGATE \
  --container-properties "{
    \"image\": \"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_COLLECT}:latest\",
    \"jobRoleArn\": \"${BATCH_JOB_ROLE_ARN}\",
    \"executionRoleArn\": \"${BATCH_JOB_ROLE_ARN}\",
    \"resourceRequirements\": [
      {\"type\": \"VCPU\",   \"value\": \"1\"},
      {\"type\": \"MEMORY\", \"value\": \"2048\"}
    ],
    \"environment\": [
      {\"name\": \"S3_RAW_BUCKET\",    \"value\": \"${S3_RAW_BUCKET}\"},
      {\"name\": \"AWS_DEFAULT_REGION\",\"value\": \"${AWS_REGION}\"}
    ],
    \"networkConfiguration\": {\"assignPublicIp\": \"ENABLED\"},
    \"logConfiguration\": {
      \"logDriver\": \"awslogs\",
      \"options\": {
        \"awslogs-group\": \"/aws/batch/${PREFIX}\",
        \"awslogs-region\": \"${AWS_REGION}\",
        \"awslogs-stream-prefix\": \"collect\"
      }
    }
  }" \
  --region "$AWS_REGION" \
  > /dev/null

ok "작업 정의 등록: $BATCH_JOB_DEF_COLLECT"

# ── 작업 정의: 데이터 정제 ────────────────────────────────────────────────────
log "Batch 작업 정의 등록: $BATCH_JOB_DEF_REFINE (정제)"

aws batch register-job-definition \
  --job-definition-name "$BATCH_JOB_DEF_REFINE" \
  --type container \
  --platform-capabilities FARGATE \
  --container-properties "{
    \"image\": \"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_REFINE}:latest\",
    \"jobRoleArn\": \"${BATCH_JOB_ROLE_ARN}\",
    \"executionRoleArn\": \"${BATCH_JOB_ROLE_ARN}\",
    \"resourceRequirements\": [
      {\"type\": \"VCPU\",   \"value\": \"2\"},
      {\"type\": \"MEMORY\", \"value\": \"4096\"}
    ],
    \"environment\": [
      {\"name\": \"S3_RAW_BUCKET\",       \"value\": \"${S3_RAW_BUCKET}\"},
      {\"name\": \"S3_PROCESSED_BUCKET\", \"value\": \"${S3_PROCESSED_BUCKET}\"},
      {\"name\": \"AWS_DEFAULT_REGION\",  \"value\": \"${AWS_REGION}\"}
    ],
    \"networkConfiguration\": {\"assignPublicIp\": \"ENABLED\"},
    \"logConfiguration\": {
      \"logDriver\": \"awslogs\",
      \"options\": {
        \"awslogs-group\": \"/aws/batch/${PREFIX}\",
        \"awslogs-region\": \"${AWS_REGION}\",
        \"awslogs-stream-prefix\": \"refine\"
      }
    }
  }" \
  --region "$AWS_REGION" \
  > /dev/null

ok "작업 정의 등록: $BATCH_JOB_DEF_REFINE"

# ── CloudWatch 로그 그룹 생성 ─────────────────────────────────────────────────
aws logs create-log-group \
  --log-group-name "/aws/batch/${PREFIX}" \
  --region "$AWS_REGION" 2>/dev/null || true

aws logs put-retention-policy \
  --log-group-name "/aws/batch/${PREFIX}" \
  --retention-in-days 30 \
  --region "$AWS_REGION" 2>/dev/null || true

ok "Batch 구성 완료"
