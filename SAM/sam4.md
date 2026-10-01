# 4. Full Stack

Full Stack 템플릿은 서버리스 백엔드와 프런트엔드 구성요소를 하나의 애플리케이션으로 시작하는 예제입니다. 아래 명령은 Node.js 22 변형을 선택합니다.

## 애플리케이션 생성

```bash
sam init --name sam-full-stack --runtime nodejs22.x --dependency-manager npm --app-template quick-start-full-stack --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-full-stack
sam validate
sam build
sam deploy --guided
```

일반 Lambda 이벤트처럼 호출하기보다 생성된 안내 문서와 스크립트에 따라 프런트엔드와 백엔드를 각각 준비하세요. 환경 설정, 빌드 산출물, 공개 URL 및 정리 방법을 확인한 뒤 배포합니다.
