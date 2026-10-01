# 3. DynamoDB 예제

이 예제는 Lambda 함수와 DynamoDB를 함께 사용하는 애플리케이션의 시작점입니다. 제공되는 관리형 템플릿은 Rust 런타임 기반입니다.

## 애플리케이션 생성

```bash
sam init --name sam-dynamodb --runtime provided.al2 --dependency-manager cargo --app-template hello-world-ddb --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-dynamodb
sam validate
sam build
sam local invoke
sam deploy --guided
```

템플릿에서 DynamoDB 테이블, 함수의 테이블 접근 권한 및 이벤트/요청 처리를 확인하세요. 테이블은 스택 삭제만으로 정리되지 않도록 설정되어 있을 수 있으므로, 배포된 리소스와 테이블 데이터를 확인한 뒤 필요하면 별도로 삭제하세요.
