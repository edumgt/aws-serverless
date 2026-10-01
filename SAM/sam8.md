# 8. Powertools for AWS Lambda

이 템플릿은 AWS Lambda Powertools를 활용해 로깅, 지표, 추적 등의 운영 기능을 애플리케이션에 추가하는 예제입니다. 아래는 Python 변형입니다.

## 애플리케이션 생성

```bash
sam init --name sam-powertools --runtime python3.13 --dependency-manager pip --app-template hello-world-powertools-python --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-powertools
sam validate
sam build
sam local invoke
sam deploy --guided
```

생성된 함수와 템플릿에서 Powertools 구성, 구조화 로그 및 계측 설정을 확인하세요. CloudWatch에서 지표나 추적을 확인하려면 해당 기능의 리소스와 권한 설정도 살펴봅니다.
