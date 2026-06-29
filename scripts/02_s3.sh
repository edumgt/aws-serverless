#!/usr/bin/env bash
# =============================================================================
# Step 2 - S3 버킷 생성 (Raw / Processed / Scripts)
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

create_bucket() {
  local bucket="$1"

  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    ok "S3 버킷 이미 존재: $bucket"
    return
  fi

  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$bucket" --region "$AWS_REGION" > /dev/null
  else
    aws s3api create-bucket --bucket "$bucket" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" > /dev/null
  fi

  # 퍼블릭 액세스 차단
  aws s3api put-public-access-block --bucket "$bucket" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  # 버전 관리 활성화
  aws s3api put-bucket-versioning --bucket "$bucket" \
    --versioning-configuration Status=Enabled

  # 태그
  aws s3api put-bucket-tagging --bucket "$bucket" \
    --tagging "TagSet=[{Key=Project,Value=${PROJECT}},{Key=Env,Value=${ENV}}]"

  ok "S3 버킷 생성: $bucket"
}

# 수명주기 정책 (Raw: 90일 후 Glacier, Processed: 180일 후 삭제)
apply_lifecycle() {
  local bucket="$1"
  local policy_file="$2"
  aws s3api put-bucket-lifecycle-configuration --bucket "$bucket" \
    --lifecycle-configuration "file://${policy_file}"
  ok "수명주기 정책 적용: $bucket"
}

log "S3 버킷 생성 중..."
create_bucket "$S3_RAW_BUCKET"
create_bucket "$S3_PROCESSED_BUCKET"
create_bucket "$S3_SCRIPTS_BUCKET"

# Raw 버킷 수명주기
LIFECYCLE_RAW=$(mktemp)
cat > "$LIFECYCLE_RAW" << EOF
{
  "Rules": [
    {
      "ID": "archive-raw-data",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Transitions": [
        {"Days": 90,  "StorageClass": "STANDARD_IA"},
        {"Days": 180, "StorageClass": "GLACIER"}
      ]
    }
  ]
}
EOF
apply_lifecycle "$S3_RAW_BUCKET" "$LIFECYCLE_RAW"
rm -f "$LIFECYCLE_RAW"

# Processed 버킷 수명주기
LIFECYCLE_PROC=$(mktemp)
cat > "$LIFECYCLE_PROC" << EOF
{
  "Rules": [
    {
      "ID": "expire-processed-data",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Transitions": [
        {"Days": 90, "StorageClass": "STANDARD_IA"}
      ],
      "Expiration": {"Days": 365}
    }
  ]
}
EOF
apply_lifecycle "$S3_PROCESSED_BUCKET" "$LIFECYCLE_PROC"
rm -f "$LIFECYCLE_PROC"

# 폴더 구조 초기화
for bucket_prefix in "daily/" "weekly/" "monthly/"; do
  aws s3api put-object --bucket "$S3_RAW_BUCKET"       --key "$bucket_prefix" --content-length 0 > /dev/null
  aws s3api put-object --bucket "$S3_PROCESSED_BUCKET" --key "$bucket_prefix" --content-length 0 > /dev/null
done
aws s3api put-object --bucket "$S3_SCRIPTS_BUCKET" --key "batch/"     --content-length 0 > /dev/null
aws s3api put-object --bucket "$S3_SCRIPTS_BUCKET" --key "glue/"      --content-length 0 > /dev/null
aws s3api put-object --bucket "$S3_SCRIPTS_BUCKET" --key "sagemaker/" --content-length 0 > /dev/null

ok "S3 버킷 구성 완료"
echo "  Raw       : s3://${S3_RAW_BUCKET}"
echo "  Processed : s3://${S3_PROCESSED_BUCKET}"
echo "  Scripts   : s3://${S3_SCRIPTS_BUCKET}"
