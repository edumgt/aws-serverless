# 6. Hello World Durable Function

이 템플릿은 Python으로 작성된 Durable Function의 작은 시작 예제입니다. 일반 Hello World 함수와 비교해 내구성 있는 실행 흐름의 기본 구조를 살펴볼 수 있습니다.

## 애플리케이션 생성

```bash
sam init --name sam-durable-python --runtime python3.13 --dependency-manager pip --app-template hello-world-durable --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-durable-python
sam validate
sam build
sam local invoke
sam deploy --guided
```

생성된 이벤트 샘플과 함수 코드를 사용해 실행 흐름을 확인하세요. Durable Functions의 전체 동작 검증은 필요한 AWS 서비스와 권한을 갖춘 계정에 배포한 뒤 진행합니다.
