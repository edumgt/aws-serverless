#!/usr/bin/env bash
# =============================================================================
# Step 3 - DynamoDB 테이블 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

log "DynamoDB 테이블 생성 중: $DYNAMODB_TABLE"

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" > /dev/null 2>&1; then
  ok "DynamoDB 테이블 이미 존재: $DYNAMODB_TABLE"
  exit 0
fi

aws dynamodb create-table \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions \
    AttributeName=ticker,AttributeType=S \
    AttributeName=date,AttributeType=S \
  --key-schema \
    AttributeName=ticker,KeyType=HASH \
    AttributeName=date,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[
    {
      "IndexName": "date-ticker-index",
      "KeySchema": [
        {"AttributeName": "date",   "KeyType": "HASH"},
        {"AttributeName": "ticker", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --tags Key=Project,Value="$PROJECT" Key=Env,Value="$ENV" \
  --region "$AWS_REGION" \
  > /dev/null

log "테이블 활성화 대기 중..."
aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"

# TTL 활성화 (분석 결과 2년 후 자동 삭제)
aws dynamodb update-time-to-live \
  --table-name "$DYNAMODB_TABLE" \
  --time-to-live-specification Enabled=true,AttributeName=ttl \
  --region "$AWS_REGION" \
  > /dev/null

# Point-in-time recovery 활성화
aws dynamodb update-continuous-backups \
  --table-name "$DYNAMODB_TABLE" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region "$AWS_REGION" \
  > /dev/null

ok "DynamoDB 테이블 생성 완료: $DYNAMODB_TABLE"
echo "  파티션 키 : ticker (종목 코드)"
echo "  정렬 키   : date (YYYY-MM-DD)"
echo "  GSI       : date-ticker-index"
