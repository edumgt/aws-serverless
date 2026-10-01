# 5. GraphQL API

GraphQL API 템플릿은 GraphQL 요청을 처리하는 서버리스 애플리케이션의 예제입니다. Node.js 런타임 변형은 API 스키마와 Lambda 연결 구조를 살펴보기에 적합합니다.

## 애플리케이션 생성

```bash
sam init --name sam-graphql --runtime nodejs22.x --dependency-manager npm --app-template graphql-api-sample-app --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-graphql
sam validate
sam build
sam deploy --guided
```

배포 결과에서 GraphQL 엔드포인트를 확인하고, 템플릿의 스키마와 리졸버를 따라 쿼리/뮤테이션 요청을 테스트하세요. 로컬 테스트 방법은 생성된 프로젝트 안내를 우선 확인합니다.
