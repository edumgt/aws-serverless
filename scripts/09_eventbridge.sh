#!/usr/bin/env bash
# =============================================================================
# Step 9 - EventBridge Scheduler 생성 (매일 장 마감 후 트리거)
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

EB_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_EVENTBRIDGE_ROLE}"
SFN_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:${SFN_STATE_MACHINE}"

log "EventBridge Scheduler 생성 중: $EVENTBRIDGE_RULE"
log "스케줄: $EVENTBRIDGE_SCHEDULE (매일 16:00 KST)"

# Step Functions에 전달할 입력 (실행 당일 날짜를 target_date로)
SCHEDULER_INPUT='{
  "target_date": "<aws.scheduler.scheduled-time>",
  "source": "eventbridge-scheduler",
  "pipeline": "'"${SFN_STATE_MACHINE}"'"
}'

if aws scheduler get-schedule --name "$EVENTBRIDGE_RULE" --region "$AWS_REGION" > /dev/null 2>&1; then
  aws scheduler update-schedule \
    --name "$EVENTBRIDGE_RULE" \
    --schedule-expression "$EVENTBRIDGE_SCHEDULE" \
    --schedule-expression-timezone "Asia/Seoul" \
    --flexible-time-window Mode=OFF \
    --target "{
      \"Arn\": \"${SFN_ARN}\",
      \"RoleArn\": \"${EB_ROLE_ARN}\",
      \"Input\": $(echo "$SCHEDULER_INPUT" | jq -c .)
    }" \
    --region "$AWS_REGION" > /dev/null
  ok "EventBridge 스케줄 업데이트: $EVENTBRIDGE_RULE"
else
  aws scheduler create-schedule \
    --name "$EVENTBRIDGE_RULE" \
    --schedule-expression "$EVENTBRIDGE_SCHEDULE" \
    --schedule-expression-timezone "Asia/Seoul" \
    --flexible-time-window Mode=OFF \
    --target "{
      \"Arn\": \"${SFN_ARN}\",
      \"RoleArn\": \"${EB_ROLE_ARN}\",
      \"Input\": $(echo "$SCHEDULER_INPUT" | jq -c .)
    }" \
    --description "주가 데이터 파이프라인 일간 트리거 (장 마감 후 16:00 KST)" \
    --state ENABLED \
    --region "$AWS_REGION" > /dev/null
  ok "EventBridge 스케줄 생성 완료: $EVENTBRIDGE_RULE"
fi

echo "  스케줄    : $EVENTBRIDGE_SCHEDULE"
echo "  시간대    : Asia/Seoul (16:00 KST)"
echo "  대상      : $SFN_ARN"
