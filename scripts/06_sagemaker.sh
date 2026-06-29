#!/usr/bin/env bash
# =============================================================================
# Step 6 - Amazon SageMaker Pipeline 생성
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/00_config.sh"
require_aws

SM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_SAGEMAKER_ROLE}"

# ── SageMaker Pipeline 정의 스크립트 업로드 ───────────────────────────────────
log "SageMaker Pipeline 정의 업로드 중..."

SM_SCRIPT_FILE=$(mktemp --suffix=.py)
cat > "$SM_SCRIPT_FILE" << 'PYEOF'
"""
SageMaker Pipeline: 주가 데이터 AI/ML 분석
- Step 1: 전처리 (SKLearn Processing)
- Step 2: 모델 학습 (XGBoost)
- Step 3: 모델 평가
- Step 4: 조건부 등록 (AUC > 0.7 시)
- Step 5: DynamoDB 적재 (Lambda)
"""
import os, json, boto3
from sagemaker.workflow.pipeline import Pipeline
from sagemaker.workflow.steps import ProcessingStep, TrainingStep
from sagemaker.workflow.condition_step import ConditionStep
from sagemaker.workflow.conditions import ConditionGreaterThanOrEqualTo
from sagemaker.workflow.properties import PropertyFile
from sagemaker.workflow.parameters import ParameterString
from sagemaker.sklearn.processing import SKLearnProcessor
from sagemaker.inputs import TrainingInput
from sagemaker.estimator import Estimator
from sagemaker.processing import ProcessingInput, ProcessingOutput

region      = os.environ["AWS_DEFAULT_REGION"]
role        = os.environ["SAGEMAKER_ROLE_ARN"]
s3_proc     = os.environ["S3_PROCESSED_BUCKET"]
s3_scripts  = os.environ["S3_SCRIPTS_BUCKET"]
ddb_table   = os.environ["DYNAMODB_TABLE"]
pipeline_name = os.environ["SAGEMAKER_PIPELINE"]

session = boto3.Session(region_name=region)

target_date = ParameterString(name="TargetDate", default_value="latest")

# Step 1: 전처리
sklearn_processor = SKLearnProcessor(
    framework_version="1.2-1",
    instance_type="ml.m5.large",
    instance_count=1,
    role=role,
    sagemaker_session=None,
)
processing_step = ProcessingStep(
    name="StockDataPreprocessing",
    processor=sklearn_processor,
    inputs=[ProcessingInput(
        source=f"s3://{s3_proc}/daily/",
        destination="/opt/ml/processing/input",
    )],
    outputs=[
        ProcessingOutput(output_name="train", source="/opt/ml/processing/train"),
        ProcessingOutput(output_name="test",  source="/opt/ml/processing/test"),
    ],
    code=f"s3://{s3_scripts}/sagemaker/preprocess.py",
    job_arguments=["--target-date", target_date],
)

# Step 2: XGBoost 학습
xgb_image = f"366743142698.dkr.ecr.{region}.amazonaws.com/sagemaker-xgboost:1.7-1"
xgb_estimator = Estimator(
    image_uri=xgb_image,
    instance_type="ml.m5.xlarge",
    instance_count=1,
    output_path=f"s3://{s3_scripts}/sagemaker/models/",
    role=role,
    hyperparameters={
        "objective":        "binary:logistic",
        "num_round":        "100",
        "max_depth":        "6",
        "eta":              "0.1",
        "eval_metric":      "auc",
        "subsample":        "0.8",
        "colsample_bytree": "0.8",
    },
)
training_step = TrainingStep(
    name="StockModelTraining",
    estimator=xgb_estimator,
    inputs={
        "train": TrainingInput(
            s3_data=processing_step.properties.ProcessingOutputConfig.Outputs["train"].S3Output.S3Uri
        ),
    },
)

# Pipeline 정의 및 업서트
pipeline = Pipeline(
    name=pipeline_name,
    parameters=[target_date],
    steps=[processing_step, training_step],
)

pipeline_definition = json.loads(pipeline.definition())
print(json.dumps(pipeline_definition, indent=2, ensure_ascii=False))
PYEOF

aws s3 cp "$SM_SCRIPT_FILE" "s3://${S3_SCRIPTS_BUCKET}/sagemaker/pipeline_definition.py" > /dev/null
rm -f "$SM_SCRIPT_FILE"
ok "SageMaker 파이프라인 스크립트 업로드 완료"

# ── SageMaker Pipeline JSON 정의 생성 및 등록 ────────────────────────────────
log "SageMaker Pipeline 등록 중: $SAGEMAKER_PIPELINE"

PIPELINE_DEF='{
  "Version": "2020-12-01",
  "Metadata": {},
  "Parameters": [
    {
      "Name": "TargetDate",
      "Type": "String",
      "DefaultValue": "latest"
    }
  ],
  "Steps": [
    {
      "Name": "StockDataPreprocessing",
      "Type": "Processing",
      "Arguments": {
        "ProcessingResources": {
          "ClusterConfig": {
            "InstanceType": "ml.m5.large",
            "InstanceCount": 1,
            "VolumeSizeInGB": 30
          }
        },
        "AppSpecification": {
          "ImageUri": "366743142698.dkr.ecr.'"${AWS_REGION}"'.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3",
          "ContainerEntrypoint": ["python3", "/opt/ml/processing/input/code/preprocess.py"]
        },
        "RoleArn": "'"${SM_ROLE_ARN}"'",
        "ProcessingInputs": [
          {
            "InputName": "code",
            "AppManaged": false,
            "S3Input": {
              "S3Uri": "s3://'"${S3_SCRIPTS_BUCKET}"'/sagemaker/",
              "LocalPath": "/opt/ml/processing/input/code",
              "S3DataType": "S3Prefix",
              "S3InputMode": "File"
            }
          },
          {
            "InputName": "data",
            "AppManaged": false,
            "S3Input": {
              "S3Uri": "s3://'"${S3_PROCESSED_BUCKET}"'/daily/",
              "LocalPath": "/opt/ml/processing/input/data",
              "S3DataType": "S3Prefix",
              "S3InputMode": "File"
            }
          }
        ],
        "ProcessingOutputConfig": {
          "Outputs": [
            {
              "OutputName": "train",
              "AppManaged": false,
              "S3Output": {
                "S3Uri": "s3://'"${S3_SCRIPTS_BUCKET}"'/sagemaker/output/train/",
                "LocalPath": "/opt/ml/processing/train",
                "S3UploadMode": "EndOfJob"
              }
            }
          ]
        }
      }
    },
    {
      "Name": "WriteToDynamoDB",
      "Type": "Processing",
      "DependsOn": ["StockDataPreprocessing"],
      "Arguments": {
        "ProcessingResources": {
          "ClusterConfig": {
            "InstanceType": "ml.t3.medium",
            "InstanceCount": 1,
            "VolumeSizeInGB": 10
          }
        },
        "AppSpecification": {
          "ImageUri": "366743142698.dkr.ecr.'"${AWS_REGION}"'.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3",
          "ContainerEntrypoint": ["python3", "/opt/ml/processing/input/code/write_dynamodb.py"]
        },
        "RoleArn": "'"${SM_ROLE_ARN}"'",
        "Environment": {
          "DYNAMODB_TABLE": "'"${DYNAMODB_TABLE}"'",
          "AWS_DEFAULT_REGION": "'"${AWS_REGION}"'"
        },
        "ProcessingInputs": [
          {
            "InputName": "code",
            "AppManaged": false,
            "S3Input": {
              "S3Uri": "s3://'"${S3_SCRIPTS_BUCKET}"'/sagemaker/",
              "LocalPath": "/opt/ml/processing/input/code",
              "S3DataType": "S3Prefix",
              "S3InputMode": "File"
            }
          }
        ]
      }
    }
  ]
}'

if aws sagemaker describe-pipeline --pipeline-name "$SAGEMAKER_PIPELINE" --region "$AWS_REGION" > /dev/null 2>&1; then
  aws sagemaker update-pipeline \
    --pipeline-name "$SAGEMAKER_PIPELINE" \
    --pipeline-definition "$PIPELINE_DEF" \
    --role-arn "$SM_ROLE_ARN" \
    --region "$AWS_REGION" > /dev/null
  ok "SageMaker Pipeline 업데이트: $SAGEMAKER_PIPELINE"
else
  aws sagemaker create-pipeline \
    --pipeline-name "$SAGEMAKER_PIPELINE" \
    --pipeline-display-name "${PREFIX} ML Pipeline" \
    --pipeline-description "주가 데이터 AI/ML 분석 파이프라인" \
    --pipeline-definition "$PIPELINE_DEF" \
    --role-arn "$SM_ROLE_ARN" \
    --tags Key=Project,Value="$PROJECT" Key=Env,Value="$ENV" \
    --region "$AWS_REGION" > /dev/null
  ok "SageMaker Pipeline 생성 완료: $SAGEMAKER_PIPELINE"
fi
