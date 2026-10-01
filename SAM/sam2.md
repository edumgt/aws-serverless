# 2. Durable Functions

Durable Functions 템플릿은 여러 단계로 이어지는 오래 실행되는 작업을 상태와 함께 처리하는 패턴을 보여줍니다. 예제는 TypeScript 기반 Node.js 애플리케이션입니다.

## 애플리케이션 생성

```bash
sam init --name sam-durable --runtime nodejs22.x --dependency-manager npm --app-template hello-durable-ts --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-durable
sam validate
sam build
sam local invoke
sam deploy --guided
```

생성된 템플릿과 코드를 확인해 시작 함수, 단계별 처리, 재시도 및 상태 관리가 어떻게 연결되는지 살펴보세요. 배포 전 애플리케이션이 생성하는 AWS 리소스를 검토하고, 테스트 후 스택을 삭제하세요.
