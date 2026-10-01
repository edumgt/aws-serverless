# 14. Step Functions와 SAM Connectors

이 템플릿은 Step Functions 워크플로가 SAM Connectors를 사용해 AWS 리소스와 통신하는 구성을 보여줍니다. Connector 선언이 리소스 간 권한을 어떻게 연결하는지 확인할 수 있습니다.

## 애플리케이션 생성

```bash
sam init --name sam-workflow-connectors --runtime python3.13 --dependency-manager pip --app-template step-functions-with-connectors --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-workflow-connectors
sam validate
sam build
sam deploy --guided
```

`template.yaml`에서 Connector 선언과 생성되는 IAM 권한을 확인하세요. 워크플로를 시작해 대상 리소스 접근이 성공하는지 검증하고, 배포 후 불필요한 리소스를 삭제합니다.
