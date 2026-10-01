# 9. EventBridge 이벤트 관리

EventBridge 템플릿은 이벤트 버스의 이벤트를 규칙으로 필터링해 Lambda 등 대상으로 전달하는 예제입니다. 기본 이벤트 기반 예제와 EventBridge Schema 기반 예제를 제공합니다.

## 애플리케이션 생성

아래는 Python의 기본 이벤트 예제입니다.

```bash
sam init --name sam-eventbridge --runtime python3.13 --dependency-manager pip --app-template eventBridge-hello-world --package-type Zip --no-interactive
```

스키마 기반 예제는 `--app-template eventBridge-schema-app`을 사용합니다.

## 실행 및 배포

```bash
cd sam-eventbridge
sam validate
sam build
sam local invoke
sam deploy --guided
```

템플릿의 이벤트 패턴, 버스 및 대상 구성을 확인하세요. AWS 콘솔이나 CLI에서 일치하는 이벤트를 전달해 배포 환경의 규칙이 Lambda를 호출하는지 검증합니다.
