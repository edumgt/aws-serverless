# 12. 머신러닝 추론 API

Machine Learning 템플릿은 사전 구성된 머신러닝 프레임워크를 컨테이너 이미지로 패키징하고 API Gateway와 Lambda를 통해 추론 요청을 처리하는 예제입니다.

## Scikit-learn 애플리케이션 생성

```bash
sam init --name sam-ml-api --package-type Image --base-image amazon/python3.12-base --dependency-manager pip --app-template ml-apigw-scikit-learn --no-interactive
```

다른 프레임워크가 필요하면 app template을 `ml-apigw-pytorch`, `ml-apigw-tensorflow` 또는 `ml-apigw-xgboost`로 바꿉니다. 각 프레임워크의 지원 런타임과 리소스 요구사항은 현재 CLI 템플릿 선택지에서 확인하세요.

## 빌드 및 배포

```bash
cd sam-ml-api
sam validate
sam build
sam deploy --guided
```

이미지 빌드에는 Docker가 필요하며 모델 및 컨테이너 크기에 따라 빌드·배포 시간이 늘어날 수 있습니다. 배포 전에 메모리, 타임아웃, 아키텍처, 이미지 크기와 추론 비용을 확인하세요.
