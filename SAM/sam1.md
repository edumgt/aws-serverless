# 1. 데이터 처리 — S3, SNS, SQS

이 템플릿은 Lambda를 S3 객체 이벤트, SNS 메시지 또는 SQS 큐와 연결하는 이벤트 기반 처리 예제입니다. 이벤트 소스가 Lambda를 호출하고, 함수가 이벤트 레코드를 처리하는 흐름을 학습합니다.

## 애플리케이션 생성

아래는 Node.js 22의 S3 이벤트 예제입니다.

```bash
sam init --name sam-data-processing --runtime nodejs22.x --dependency-manager npm --app-template quick-start-s3 --package-type Zip --no-interactive
```

다른 이벤트를 선택하려면 `--app-template`을 `quick-start-sns` 또는 `quick-start-sqs`로 바꿉니다. .NET 템플릿은 `quick-start-s3`, `quick-start-sqs`, `quickstart-sns`가 별도 ID로 제공될 수 있으므로 현재 CLI 선택지에서 확인하세요.

## 실행 및 배포

```bash
cd sam-data-processing
sam validate
sam build
sam local invoke
sam deploy --guided
```

S3/SNS/SQS의 실제 전달 동작은 배포 후 각 이벤트 소스를 구성해 확인합니다. 배포된 스택과 이벤트 소스 리소스를 함께 정리하세요.
