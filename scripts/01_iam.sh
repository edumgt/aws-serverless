#!/usr/bin/env bash
# =============================================================================
# Step 1 - IAM 역할 및 정책 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

create_role() {
  local role_name="$1"
  local trust_policy="$2"
  local description="$3"

  if aws iam get-role --role-name "$role_name" > /dev/null 2>&1; then
    ok "IAM 역할 이미 존재: $role_name"
    return
  fi

  aws iam create-role \
    --role-name "$role_name" \
    --assume-role-policy-document "$trust_policy" \
    --description "$description" \
    --tags Key=Project,Value="$PROJECT" Key=Env,Value="$ENV" \
    > /dev/null

  ok "IAM 역할 생성: $role_name"
}

attach_policy() {
  local role_name="$1"
  local policy_arn="$2"
  aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null || true
}

# ── Lambda 실행 역할 ───────────────────────────────────────────────────────────
log "Lambda 역할 생성 중..."
create_role "$IAM_LAMBDA_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "Lambda API Handler Role"

attach_policy "$IAM_LAMBDA_ROLE" "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
attach_policy "$IAM_LAMBDA_ROLE" "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"

# ── Batch 실행 역할 ────────────────────────────────────────────────────────────
log "Batch 역할 생성 중..."
create_role "$IAM_BATCH_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "batch.amazonaws.com"},
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}' "Batch Job Execution Role"

attach_policy "$IAM_BATCH_ROLE" "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
attach_policy "$IAM_BATCH_ROLE" "arn:aws:iam::aws:policy/AmazonS3FullAccess"
attach_policy "$IAM_BATCH_ROLE" "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"

# Batch 서비스 역할 별도 생성
create_role "${PREFIX}-batch-service-role" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "batch.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "Batch Service Role"
attach_policy "${PREFIX}-batch-service-role" "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"

# ── Step Functions 역할 ────────────────────────────────────────────────────────
log "Step Functions 역할 생성 중..."
create_role "$IAM_STEP_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "states.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "Step Functions Workflow Role"

attach_policy "$IAM_STEP_ROLE" "arn:aws:iam::aws:policy/AWSBatchFullAccess"
attach_policy "$IAM_STEP_ROLE" "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
attach_policy "$IAM_STEP_ROLE" "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
attach_policy "$IAM_STEP_ROLE" "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
attach_policy "$IAM_STEP_ROLE" "arn:aws:iam::aws:policy/CloudWatchFullAccess"

# ── Glue 역할 ─────────────────────────────────────────────────────────────────
log "Glue 역할 생성 중..."
create_role "$IAM_GLUE_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "glue.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "Glue ETL Role"

attach_policy "$IAM_GLUE_ROLE" "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
attach_policy "$IAM_GLUE_ROLE" "arn:aws:iam::aws:policy/AmazonS3FullAccess"

# ── SageMaker 역할 ────────────────────────────────────────────────────────────
log "SageMaker 역할 생성 중..."
create_role "$IAM_SAGEMAKER_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "sagemaker.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "SageMaker ML Role"

attach_policy "$IAM_SAGEMAKER_ROLE" "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
attach_policy "$IAM_SAGEMAKER_ROLE" "arn:aws:iam::aws:policy/AmazonS3FullAccess"
attach_policy "$IAM_SAGEMAKER_ROLE" "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

# ── EventBridge 역할 ──────────────────────────────────────────────────────────
log "EventBridge 역할 생성 중..."
create_role "$IAM_EVENTBRIDGE_ROLE" '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "scheduler.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}' "EventBridge Scheduler Role"

EVENTBRIDGE_POLICY_DOC="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Action\": \"states:StartExecution\",
    \"Resource\": \"arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:${SFN_STATE_MACHINE}\"
  }]
}"

POLICY_NAME="${PREFIX}-eventbridge-sfn-policy"
if ! aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" > /dev/null 2>&1; then
  POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$EVENTBRIDGE_POLICY_DOC" \
    --query 'Policy.Arn' --output text)
  ok "IAM 정책 생성: $POLICY_NAME"
else
  POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
  ok "IAM 정책 이미 존재: $POLICY_NAME"
fi
attach_policy "$IAM_EVENTBRIDGE_ROLE" "$POLICY_ARN"

ok "모든 IAM 역할 설정 완료"
