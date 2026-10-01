# 15. 예약 작업

Scheduled task 템플릿은 일정에 따라 Lambda를 호출하는 EventBridge 규칙 예제입니다. 아래는 Node.js 22 변형입니다.

## 애플리케이션 생성

```bash
sam init --name sam-scheduled-task --runtime nodejs22.x --dependency-manager npm --app-template quick-start-cloudwatch-events --package-type Zip --no-interactive
```

## 실행 및 배포

```bash
cd sam-scheduled-task
sam validate
sam build
sam local invoke
sam deploy --guided
```

예약 표현식과 시간대 관련 동작을 템플릿에서 확인하세요. 배포 후 EventBridge 규칙이 활성 상태인지, 실행 기록과 Lambda 로그가 생성되는지 살펴봅니다. 실습을 마치면 스택을 삭제해 규칙의 반복 호출을 중지하세요.
