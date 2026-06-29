#!/usr/bin/env bash
# =============================================================================
# Step 7 - Lambda 함수 및 API Gateway 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_LAMBDA_ROLE}"
LAMBDA_DIR="$(dirname "$0")/lambda"
LAMBDA_ZIP="/tmp/${LAMBDA_FUNCTION}.zip"

# ── Lambda 패키징 ─────────────────────────────────────────────────────────────
log "Lambda 함수 패키징 중..."
cd "$LAMBDA_DIR"
zip -q "$LAMBDA_ZIP" handler.py
cd - > /dev/null
ok "패키지 생성: $LAMBDA_ZIP"

# ── Lambda 함수 생성 / 업데이트 ───────────────────────────────────────────────
log "Lambda 함수 배포 중: $LAMBDA_FUNCTION"

if aws lambda get-function --function-name "$LAMBDA_FUNCTION" --region "$AWS_REGION" > /dev/null 2>&1; then
  aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION" \
    --zip-file "fileb://${LAMBDA_ZIP}" \
    --region "$AWS_REGION" > /dev/null
  ok "Lambda 코드 업데이트: $LAMBDA_FUNCTION"
else
  aws lambda create-function \
    --function-name "$LAMBDA_FUNCTION" \
    --runtime python3.12 \
    --role "$LAMBDA_ROLE_ARN" \
    --handler handler.handler \
    --zip-file "fileb://${LAMBDA_ZIP}" \
    --environment "Variables={DYNAMODB_TABLE=${DYNAMODB_TABLE},AWS_REGION_NAME=${AWS_REGION}}" \
    --timeout 30 \
    --memory-size 256 \
    --tags Project="$PROJECT",Env="$ENV" \
    --region "$AWS_REGION" \
    > /dev/null

  log "Lambda 활성화 대기 중..."
  aws lambda wait function-active --function-name "$LAMBDA_FUNCTION" --region "$AWS_REGION"
  ok "Lambda 함수 생성 완료: $LAMBDA_FUNCTION"
fi

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$LAMBDA_FUNCTION" \
  --query 'Configuration.FunctionArn' --output text --region "$AWS_REGION")

# CloudWatch 로그 그룹
aws logs create-log-group \
  --log-group-name "/aws/lambda/${LAMBDA_FUNCTION}" \
  --region "$AWS_REGION" 2>/dev/null || true
aws logs put-retention-policy \
  --log-group-name "/aws/lambda/${LAMBDA_FUNCTION}" \
  --retention-in-days 14 --region "$AWS_REGION" 2>/dev/null || true

# ── API Gateway REST API 생성 ─────────────────────────────────────────────────
log "API Gateway 생성 중: $APIGW_NAME"

EXISTING_APIS=$(aws apigateway get-rest-apis \
  --query "items[?name=='${APIGW_NAME}'].id" --output text --region "$AWS_REGION")

if [[ -n "$EXISTING_APIS" ]]; then
  API_ID="$EXISTING_APIS"
  ok "API Gateway 이미 존재: $API_ID"
else
  API_ID=$(aws apigateway create-rest-api \
    --name "$APIGW_NAME" \
    --description "Stock Pipeline Analysis API" \
    --endpoint-configuration types=REGIONAL \
    --tags Project="$PROJECT",Env="$ENV" \
    --query 'id' --output text --region "$AWS_REGION")
  ok "API Gateway 생성: $API_ID"
fi

ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[?path==`/`].id' --output text --region "$AWS_REGION")

# /analysis 리소스
ANALYSIS_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query "items[?path=='/analysis'].id" --output text --region "$AWS_REGION")

if [[ -z "$ANALYSIS_ID" ]]; then
  ANALYSIS_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" --parent-id "$ROOT_ID" \
    --path-part "analysis" \
    --query 'id' --output text --region "$AWS_REGION")
fi

# /analysis/{ticker} 리소스
TICKER_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query "items[?path=='/analysis/{ticker}'].id" --output text --region "$AWS_REGION")

if [[ -z "$TICKER_ID" ]]; then
  TICKER_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" --parent-id "$ANALYSIS_ID" \
    --path-part "{ticker}" \
    --query 'id' --output text --region "$AWS_REGION")
fi

setup_method() {
  local resource_id="$1"
  local path="$2"

  aws apigateway put-method \
    --rest-api-id "$API_ID" --resource-id "$resource_id" \
    --http-method GET --authorization-type NONE \
    --region "$AWS_REGION" 2>/dev/null || true

  aws apigateway put-integration \
    --rest-api-id "$API_ID" --resource-id "$resource_id" \
    --http-method GET --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region "$AWS_REGION" 2>/dev/null || true

  ok "API 메서드 설정: GET $path"
}

setup_method "$ANALYSIS_ID"  "/analysis"
setup_method "$TICKER_ID"    "/analysis/{ticker}"

# Lambda 권한 부여
for STMT_ID in "apigw-analysis" "apigw-ticker"; do
  aws lambda remove-permission \
    --function-name "$LAMBDA_FUNCTION" \
    --statement-id "$STMT_ID" \
    --region "$AWS_REGION" 2>/dev/null || true
done

aws lambda add-permission \
  --function-name "$LAMBDA_FUNCTION" \
  --statement-id "apigw-analysis" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/GET/analysis" \
  --region "$AWS_REGION" > /dev/null

aws lambda add-permission \
  --function-name "$LAMBDA_FUNCTION" \
  --statement-id "apigw-ticker" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/GET/analysis/*" \
  --region "$AWS_REGION" > /dev/null

# ── 배포 ──────────────────────────────────────────────────────────────────────
STAGE="${ENV}"
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --description "Deploy ${ENV}" \
  --region "$AWS_REGION" > /dev/null

ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}"
ok "API Gateway 배포 완료"
echo "  Endpoint : ${ENDPOINT}"
echo "  분석 목록: GET ${ENDPOINT}/analysis?date=YYYY-MM-DD"
echo "  종목 조회: GET ${ENDPOINT}/analysis/{ticker}?date=YYYY-MM-DD"

# 환경변수 업데이트
aws lambda update-function-configuration \
  --function-name "$LAMBDA_FUNCTION" \
  --environment "Variables={DYNAMODB_TABLE=${DYNAMODB_TABLE},AWS_REGION_NAME=${AWS_REGION},API_ENDPOINT=${ENDPOINT}}" \
  --region "$AWS_REGION" > /dev/null

rm -f "$LAMBDA_ZIP"
