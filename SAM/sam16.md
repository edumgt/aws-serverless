# 16. 서버리스 웹 API

Serverless API 템플릿은 HTTP 요청을 API Gateway에서 Lambda로 전달하는 웹 API 예제입니다. 아래는 Node.js 22 변형입니다.

## 애플리케이션 생성

```bash
sam init --name sam-web-api --runtime nodejs22.x --dependency-manager npm --app-template quick-start-web --package-type Zip --no-interactive
```

## 로컬 실행 및 배포

```bash
cd sam-web-api
sam validate
sam build
sam local start-api
```

로컬 서버가 출력한 URL을 별도 터미널에서 템플릿에 정의된 경로로 호출합니다.

```bash
curl http://127.0.0.1:3000/<경로>
```

AWS 배포는 `sam deploy --guided`로 진행하고, 출력된 API URL로 동일한 라우트를 테스트합니다.
