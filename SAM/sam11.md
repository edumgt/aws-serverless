# 11. Lambda 응답 스트리밍

응답 스트리밍 템플릿은 Lambda가 응답 데이터를 한 번에 반환하지 않고 스트림으로 전달하는 패턴을 보여줍니다. 아래는 Node.js 22 변형입니다.

## 애플리케이션 생성

```bash
sam init --name sam-response-streaming --runtime nodejs22.x --dependency-manager npm --app-template response-streaming --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-response-streaming
sam validate
sam build
sam deploy --guided
```

응답 스트리밍은 호출 경로와 통합 방식에 따라 확인 방법이 다를 수 있습니다. 생성된 템플릿의 API 및 핸들러 구성을 확인하고, 지원되는 배포 엔드포인트에서 클라이언트가 청크 응답을 받는지 테스트하세요.
