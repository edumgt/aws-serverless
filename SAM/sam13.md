# 13. Step Functions 다단계 워크플로

이 템플릿은 여러 Lambda 작업을 AWS Step Functions 상태 머신으로 연결하는 다단계 워크플로 예제입니다. 아래 명령은 Python 변형을 만듭니다.

## 애플리케이션 생성

```bash
sam init --name sam-workflow --runtime python3.13 --dependency-manager pip --app-template step-functions-sample-app --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-workflow
sam validate
sam build
sam deploy --guided
```

배포 후 Step Functions 콘솔에서 상태 머신 정의와 실행 이력을 확인합니다. 각 상태의 입력/출력, 실패 처리 및 재시도 동작을 읽고, 필요에 따라 상태 머신 실행을 시작해 흐름을 검증하세요.
