#!/usr/bin/env bash
# =============================================================================
# Step 8 - AWS Step Functions State Machine 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

SFN_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_STEP_ROLE}"
WORKFLOW_TEMPLATE="$(dirname "$0")/step-functions/workflow.json"

log "Step Functions 상태 머신 생성 중: $SFN_STATE_MACHINE"

# 변수 치환 후 정의 생성
DEFINITION=$(sed \
  -e "s|\${BATCH_JOB_QUEUE}|${BATCH_JOB_QUEUE}|g" \
  -e "s|\${BATCH_JOB_DEF_COLLECT}|${BATCH_JOB_DEF_COLLECT}|g" \
  -e "s|\${BATCH_JOB_DEF_REFINE}|${BATCH_JOB_DEF_REFINE}|g" \
  -e "s|\${GLUE_JOB}|${GLUE_JOB}|g" \
  -e "s|\${S3_RAW_BUCKET}|${S3_RAW_BUCKET}|g" \
  -e "s|\${S3_PROCESSED_BUCKET}|${S3_PROCESSED_BUCKET}|g" \
  -e "s|\${SAGEMAKER_PIPELINE}|${SAGEMAKER_PIPELINE}|g" \
  -e "s|\${SNS_ALERT_TOPIC}|arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PREFIX}-alerts|g" \
  "$WORKFLOW_TEMPLATE")

SFN_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:${SFN_STATE_MACHINE}"

if aws stepfunctions describe-state-machine --state-machine-arn "$SFN_ARN" --region "$AWS_REGION" > /dev/null 2>&1; then
  aws stepfunctions update-state-machine \
    --state-machine-arn "$SFN_ARN" \
    --definition "$DEFINITION" \
    --role-arn "$SFN_ROLE_ARN" \
    --region "$AWS_REGION" > /dev/null
  ok "Step Functions 상태 머신 업데이트: $SFN_STATE_MACHINE"
else
  aws stepfunctions create-state-machine \
    --name "$SFN_STATE_MACHINE" \
    --definition "$DEFINITION" \
    --role-arn "$SFN_ROLE_ARN" \
    --type STANDARD \
    --logging-configuration "{
      \"level\": \"ALL\",
      \"includeExecutionData\": true,
      \"destinations\": [{
        \"cloudWatchLogsLogGroup\": {
          \"logGroupArn\": \"arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:log-group:/aws/states/${PREFIX}:*\"
        }
      }]
    }" \
    --tags key=Project,value="$PROJECT" key=Env,value="$ENV" \
    --region "$AWS_REGION" > /dev/null

  ok "Step Functions 상태 머신 생성 완료: $SFN_STATE_MACHINE"
fi

# CloudWatch 로그 그룹
aws logs create-log-group \
  --log-group-name "/aws/states/${PREFIX}" \
  --region "$AWS_REGION" 2>/dev/null || true
aws logs put-retention-policy \
  --log-group-name "/aws/states/${PREFIX}" \
  --retention-in-days 90 --region "$AWS_REGION" 2>/dev/null || true

echo "  State Machine ARN: $SFN_ARN"
