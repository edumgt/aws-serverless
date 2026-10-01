# 10. Lambda와 EFS

EFS 템플릿은 Lambda 함수가 네트워크 파일 시스템을 마운트해 파일을 읽고 쓰는 구성을 예시합니다. 일반 Lambda와 달리 VPC, 서브넷, 보안 그룹 및 EFS 액세스 포인트 설정이 필요합니다.

## 애플리케이션 생성

```bash
sam init --name sam-efs --runtime python3.13 --dependency-manager pip --app-template efs-sample-app --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-efs
sam validate
sam build
sam deploy --guided
```

EFS 및 네트워크 리소스는 계정의 VPC 구성에 맞춰 검토·수정한 뒤 배포하세요. 일반적인 로컬 Lambda 호출만으로 실제 EFS 마운트까지 검증되지는 않습니다. 사용 후 생성된 파일 시스템과 네트워크 리소스를 확인하고 정리하세요.
