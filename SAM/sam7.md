# 7. Hello World

Hello World는 Lambda와 SAM을 처음 시작할 때 사용하는 기본 템플릿입니다. 함수, `template.yaml`, 로컬 이벤트와 테스트 코드의 관계를 확인할 수 있습니다.

## Zip 애플리케이션 생성

```bash
sam init --name sam-hello-world --runtime python3.13 --dependency-manager pip --app-template hello-world --package-type Zip --no-interactive
```

컨테이너 이미지 패키지 예제가 필요하면 다음과 같이 생성합니다.

```bash
sam init --name sam-hello-world-image --package-type Image --base-image amazon/python3.13-base --dependency-manager pip --app-template hello-world-lambda-image --no-interactive
```

## 실행 및 배포

```bash
cd sam-hello-world
sam validate
sam build
sam local invoke
sam deploy --guided
```

HTTP 이벤트가 포함된 생성물이라면 `sam local start-api`로 로컬 API도 확인할 수 있습니다. 이미지 패키지는 로컬 빌드와 실행에 Docker가 필요합니다.
