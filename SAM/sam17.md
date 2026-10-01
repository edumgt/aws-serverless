# 17. Serverless Connector Hello World

이 예제는 SAM Connector를 사용해 애플리케이션 리소스 간 필요한 권한과 연결을 선언하는 방법을 보여줍니다. Python 템플릿을 사용합니다.

## 애플리케이션 생성

```bash
sam init --name sam-connector --runtime python3.13 --dependency-manager pip --app-template hello-world-connector --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-connector
sam validate
sam build
sam local invoke
sam deploy --guided
```

생성된 `template.yaml`에서 Connector의 `Source`, `Destination` 및 접근 권한을 확인합니다. Connector가 어떤 IAM 권한을 추가하는지 검토한 뒤 배포하세요.
