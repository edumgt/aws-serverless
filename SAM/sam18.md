# 18. 독립 실행 Lambda 함수

Standalone function 템플릿은 API나 이벤트 소스 없이 시작하는 단일 Lambda 함수의 기본 구조를 제공합니다. 아래는 Node.js 22 변형입니다.

## 애플리케이션 생성

```bash
sam init --name sam-standalone-function --runtime nodejs22.x --dependency-manager npm --app-template quick-start-from-scratch --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-standalone-function
sam validate
sam build
sam local invoke
sam deploy --guided
```

이 템플릿을 출발점으로 필요한 이벤트를 `template.yaml`의 함수 리소스에 추가할 수 있습니다. AWS 이벤트를 연결하기 전에는 함수의 입력 이벤트와 IAM 권한을 함께 설계하세요.
